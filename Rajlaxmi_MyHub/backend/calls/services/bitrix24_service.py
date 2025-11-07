import requests
import json
import logging
import base64
import os
import time
import tempfile
from django.conf import settings
from django.utils import timezone
from calls.models import Bitrix24UserMapping, Bitrix24SyncLog

logger = logging.getLogger(__name__)

class Bitrix24Service:
    def __init__(self):
        self.webhook_url = getattr(settings, 'BITRIX24_WEBHOOK_URL', '')
        self.domain = getattr(settings, 'BITRIX24_DOMAIN', '')
        self.app_domain = getattr(settings, 'APP_DOMAIN', '192.168.1.17:8000')  # Add this
        
        print(f"🔗 Bitrix24 webhook URL: {self.webhook_url}")
        print(f"🌐 App domain: {self.app_domain}")
        
        if not self.webhook_url:
            print("❌ BITRIX24_WEBHOOK_URL not configured in settings!")
    
    def _log_sync_attempt(self, call_log, sync_type, status, request_payload, response_data, error_message="", duration_ms=0):
        """Log synchronization attempts to database"""
        try:
            # Truncate long values to prevent database errors
            if sync_type and len(sync_type) > 20:
                sync_type = sync_type[:20]
            if status and len(status) > 20:
                status = status[:20]
            if error_message and len(error_message) > 255:
                error_message = error_message[:255]
            
            # Convert request_payload and response_data to strings with length limits
            request_str = str(request_payload)
            response_str = str(response_data)
            
            if len(request_str) > 1000:
                request_str = request_str[:1000] + "...(truncated)"
            if len(response_str) > 1000:
                response_str = response_str[:1000] + "...(truncated)"
            
            Bitrix24SyncLog.objects.create(
                call_log=call_log,
                sync_type=sync_type,
                status=status,
                request_payload=request_str,
                response_data=response_str,
                error_message=error_message,
                duration_ms=duration_ms
            )
        except Exception as e:
            print(f"❌ Failed to log sync attempt: {e}")
    
    def _map_to_bitrix_user(self, django_user_id):
        """Map Django user ID to Bitrix24 user ID"""
        try:
            mapping = Bitrix24UserMapping.objects.filter(
                django_user_id=django_user_id,
                is_active=True
            ).first()
            
            if mapping:
                print(f"👤 User mapping found: {django_user_id} -> {mapping.bitrix_user_id}")
                return mapping.bitrix_user_id
            else:
                print(f"⚠️ No mapping found for user {django_user_id}, using default ID 1")
                return 1  # Default to admin user
        except Exception as e:
            print(f"❌ Error in user mapping: {e}")
            return 1
    
    def _make_bitrix_request(self, endpoint, payload, timeout=10, call_log=None, sync_type="api_call"):
        """Make API request to Bitrix24 with logging"""
        start_time = time.time()
        
        try:
            response = requests.post(endpoint, json=payload, timeout=timeout)
            duration_ms = int((time.time() - start_time) * 1000)
            
            result = response.json()
            
            # Log the sync attempt
            if call_log:
                status = 'success' if result.get('result') else 'failed'
                error_msg = result.get('error_description', '') if not result.get('result') else ""
                self._log_sync_attempt(call_log, sync_type, status, payload, result, error_msg, duration_ms)
            
            return response, result
            
        except Exception as e:
            duration_ms = int((time.time() - start_time) * 1000)
            
            if call_log:
                self._log_sync_attempt(call_log, sync_type, 'failed', payload, {}, str(e), duration_ms)
            
            raise e

    def _download_file_as_base64(self, url):
        """Download file and return base64 encoded content"""
        try:
            response = requests.get(url, timeout=30)
            if response.status_code == 200:
                return base64.b64encode(response.content).decode('utf-8')
            else:
                print(f"❌ Failed to download file: HTTP {response.status_code}")
                return None
        except Exception as e:
            print(f"❌ File download failed: {str(e)}")
            return None

    def _get_drive_file_url(self, file_id, call_log=None):
        """Get the actual playable URL from Bitrix24 Drive file ID"""
        if not self.webhook_url:
            return None
        
        endpoint = f"{self.webhook_url}disk.file.get"
        payload = {
            'id': file_id
        }
        
        try:
            response, result = self._make_bitrix_request(endpoint, payload, call_log=call_log, sync_type='get_file_url')
            
            if result.get('result'):
                file_data = result['result']
                # Try different URL fields
                download_url = file_data.get('DOWNLOAD_URL') or file_data.get('URL') or file_data.get('FILE_URL')
                
                if download_url:
                    print(f"✅ Got Drive file URL: {download_url}")
                    return download_url
                else:
                    print(f"❌ No download URL found in file data: {file_data}")
                    return None
            else:
                print(f"❌ Failed to get file data: {result}")
                return None
                
        except Exception as e:
            print(f"❌ Error getting file URL: {str(e)}")
            return None

    def _upload_recording_to_drive(self, recording_url, call_log=None):
        """Upload recording to Bitrix24 Drive and return file info with URL"""
        try:
            print(f"📥 Downloading recording from: {recording_url}")
            
            # Download recording with audio-specific headers
            headers = {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                'Accept': 'audio/mpeg, audio/*'
            }
            
            response = requests.get(recording_url, headers=headers, timeout=60)
            if response.status_code != 200:
                print(f"❌ Failed to download recording: HTTP {response.status_code}")
                return None
            
            file_size = len(response.content)
            print(f"📦 Downloaded recording: {file_size} bytes")
            
            if file_size == 0:
                print(f"❌ Downloaded file is empty")
                return None
            
            # Create temp file with proper audio extension
            with tempfile.NamedTemporaryFile(delete=False, suffix='.mp3') as temp_file:
                temp_file.write(response.content)
                temp_path = temp_file.name
            
            # Create descriptive filename
            timestamp = timezone.now().strftime('%Y%m%d_%H%M%S')
            filename = f"call_recording_{timestamp}.mp3"
            
            print(f"📤 Uploading to Bitrix24 Drive: {filename}")
            file_info = self.upload_file_to_bitrix_drive(temp_path, filename, call_log)
            
            # Cleanup
            os.unlink(temp_path)
            
            if file_info and file_info.get('file_id'):
                print(f"✅ Successfully uploaded to Drive, file ID: {file_info['file_id']}")
                
                # Get the actual playable URL
                playable_url = self._get_drive_file_url(file_info['file_id'], call_log)
                file_info['playable_url'] = playable_url
                
                return file_info
            else:
                print(f"❌ Drive upload failed - no file ID returned")
                return None
                
        except Exception as e:
            print(f"❌ Drive upload failed: {str(e)}")
            return None

    def get_bitrix_users(self):
        """Get list of valid Bitrix24 users for mapping"""
        if not self.webhook_url:
            return []
            
        endpoint = f"{self.webhook_url}user.get"
        
        try:
            response, result = self._make_bitrix_request(endpoint, {})
            
            if result.get('result'):
                users = result['result']
                print("✅ Valid Bitrix24 Users:")
                for user in users:
                    print(f"   - ID: {user['ID']}, Name: {user['NAME']} {user['LAST_NAME']} ({user['EMAIL']})")
                return users
            return []
            
        except Exception as e:
            print(f"❌ Error getting Bitrix24 users: {e}")
            return []
    
    def search_existing_lead_by_phone(self, phone_number):
        """Search for existing lead by phone number"""
        if not self.webhook_url:
            return None
            
        endpoint = f"{self.webhook_url}crm.lead.list"
        
        payload = {
            'filter': {'PHONE': phone_number},
            'select': ['ID', 'TITLE', 'NAME', 'PHONE', 'STATUS_ID'],
            'order': {'DATE_CREATE': 'DESC'}
        }
        
        print(f"🔍 Searching lead for: {phone_number}")
        
        try:
            response, result = self._make_bitrix_request(endpoint, payload)
            
            if result.get('result') and len(result['result']) > 0:
                existing_lead = result['result'][0]
                print(f"✅ Found existing lead: {existing_lead['ID']} - {existing_lead.get('TITLE', 'No Title')}")
                return existing_lead
            
            print(f"❌ No existing lead found for: {phone_number}")
            return None
            
        except Exception as e:
            print(f"🔍 Error searching lead: {str(e)}")
            return None

    def search_existing_contact_by_phone(self, phone_number):
        """Search for existing contact by phone number"""
        if not self.webhook_url:
            return None
            
        endpoint = f"{self.webhook_url}crm.contact.list"
        
        payload = {
            'filter': {'PHONE': phone_number},
            'select': ['ID', 'NAME', 'LAST_NAME', 'PHONE', 'EMAIL'],
            'order': {'DATE_CREATE': 'DESC'}
        }
        
        print(f"🔍 Searching existing contact for: {phone_number}")
        
        try:
            response, result = self._make_bitrix_request(endpoint, payload)
            
            if result.get('result') and len(result['result']) > 0:
                contact = result['result'][0]
                print(f"✅ Found existing contact: {contact['ID']} - {contact.get('NAME', 'No Name')}")
                return contact
            
            return None
            
        except Exception as e:
            print(f"🔍 Error searching contact: {str(e)}")
            return None

    def create_or_get_contact(self, phone_number, caller_name=""):
        """Create new contact or return existing one"""
        # First search for existing contact
        existing_contact = self.search_existing_contact_by_phone(phone_number)
        
        if existing_contact:
            return existing_contact['ID']
        
        # Create new contact
        endpoint = f"{self.webhook_url}crm.contact.add"
        
        contact_data = {
            'fields': {
                'NAME': caller_name or f"Caller {phone_number}",
                'PHONE': [{'VALUE': phone_number, 'VALUE_TYPE': 'WORK'}],
                'OPENED': 'Y',
                'TYPE_ID': 'CLIENT'
            }
        }
        
        print(f"🆕 Creating new contact for: {phone_number}")
        
        try:
            response, result = self._make_bitrix_request(endpoint, contact_data)
            
            if result.get('result'):
                contact_id = result['result']
                print(f"✅ Created new contact: {contact_id}")
                return contact_id
            else:
                print(f"❌ Failed to create contact: {result}")
                return None
                
        except Exception as e:
            print(f"❌ Error creating contact: {str(e)}")
            return None

    def create_or_get_lead(self, phone_number, caller_name="", contact_id=None):
        """Create new lead OR return existing one"""
        print(f"🔄 create_or_get_lead called for: {phone_number}")
        
        # First search for existing lead
        existing_lead = self.search_existing_lead_by_phone(phone_number)
        
        if existing_lead:
            lead_id = existing_lead['ID']
            print(f"🎯 Reusing existing lead: {lead_id}")
            return lead_id
        
        # Create new lead if not found
        endpoint = f"{self.webhook_url}crm.lead.add"
        
        lead_title = f"Call Lead: {caller_name}" if caller_name else f"Call Lead: {phone_number}"
        
        lead_data = {
            'fields': {
                'TITLE': lead_title,
                'NAME': caller_name or f"Caller {phone_number}",
                'PHONE': [{'VALUE': phone_number, 'VALUE_TYPE': 'WORK'}],
                'SOURCE_ID': 'CALL',
                'SOURCE_DESCRIPTION': 'Auto-created from call system',
                'STATUS_ID': 'NEW',
                'OPENED': 'Y',
                'ASSIGNED_BY_ID': 1,
                'COMMENTS': f"Auto-created from call system - {phone_number}",
                'OPPORTUNITY': 0,
                'CURRENCY_ID': 'USD'
            }
        }
        
        # Link to contact if available
        if contact_id:
            lead_data['fields']['CONTACT_ID'] = contact_id
        
        print(f"🆕 Creating NEW lead for: {phone_number}")
        
        try:
            response, result = self._make_bitrix_request(endpoint, lead_data)
            
            if result.get('result'):
                lead_id = result['result']
                print(f"✅ Success: Created new lead: {lead_id}")
                return lead_id
            else:
                print(f"❌ Failed to create lead: {result}")
                return None
                
        except Exception as e:
            print(f"❌ Error creating lead: {str(e)}")
            return None

    def add_call_to_lead_timeline(self, lead_id, call_data, call_log=None):
        """Add call record to lead's timeline"""
        if not self.webhook_url:
            return False
            
        endpoint = f"{self.webhook_url}crm.timeline.comment.add"
        
        call_type = call_data.get('call_type', 'incoming').title()
        duration = call_data.get('duration', 0)
        
        comment_text = f"""
📞 {call_type} Call
Phone: {call_data.get('phone_number', '')}
Duration: {duration} seconds
Time: {call_data.get('start_time', '')}
        """.strip()

        timeline_data = {
            'fields': {
                'ENTITY_ID': int(lead_id),
                'ENTITY_TYPE': 'lead',
                'COMMENT': comment_text
            }
        }
        
        print(f"📝 Adding call to lead timeline: {lead_id}")
        
        try:
            response, result = self._make_bitrix_request(endpoint, timeline_data, call_log=call_log, sync_type='timeline_comment')
            
            if result.get('result'):
                print(f"✅ Call added to lead {lead_id} timeline")
                return True
            else:
                print(f"❌ Failed to add call to timeline: {result}")
                return False
                
        except Exception as e:
            print(f"❌ Error adding call to timeline: {str(e)}")
            return False

    def add_recording_to_lead_timeline(self, lead_id, recording_url, call_data, call_log=None):
        """Add recording using multiple display methods"""
        if not self.webhook_url:
            return False
        
        print(f"🎵 Adding recording to lead {lead_id}")
        
        # Upload to Drive and get playable URL
        drive_file_info = self._upload_recording_to_drive(recording_url, call_log)
        
        if not drive_file_info or not drive_file_info.get('playable_url'):
            print(f"❌ Failed to get playable URL from Drive")
            return self._add_recording_fallback(lead_id, recording_url, call_data, call_log)
        
        drive_file_id = drive_file_info['file_id']
        playable_url = drive_file_info['playable_url']
        
        print(f"🎵 Using Drive file ID: {drive_file_id}, URL: {playable_url}")
        
        # Try different display methods
        methods = [
            self._add_recording_html_links,        # HTML styled links (recommended)
            self._add_recording_bitrix_disk,       # Bitrix24 native disk embedding
            self._add_recording_simple_links,      # Simple text links
            self._add_recording_minimal_player,    # HTML5 audio player
        ]
        
        for method in methods:
            print(f"🔄 Trying {method.__name__}...")
            success = method(lead_id, playable_url, call_data, call_log, drive_file_id)
            if success:
                print(f"✅ Success with {method.__name__}")
                return True
            else:
                print(f"❌ {method.__name__} failed, trying next...")
        
        print(f"❌ All recording display methods failed")
        return False

    def _add_recording_html_links(self, lead_id, playable_url, call_data, call_log=None, drive_file_id=None):
        """HTML styled links that work in Bitrix24 with recording URL"""
        print(f"🎵 Creating HTML links interface")
        
        duration = call_data.get('duration', 0)
        call_type = call_data.get('call_type', 'incoming').title()
        phone = call_data.get('phone_number', '')
        
        # Format duration display
        duration_minutes = duration / 60.0
        duration_display = f"{duration_minutes:.2f}"
        
        # Get current time for recording timestamp
        current_time = timezone.now().strftime('%I:%M %p')
        current_date = timezone.now().strftime('%Y-%m-%d %I:%M %p')
        
        # Create recording URL for the Play Recording button
        recording_url = None
        if call_log and hasattr(call_log, 'recording') and call_log.recording:
            # Use the direct recording URL from the call_log
            recording_url = f"http://192.168.1.17:8000{call_log.recording.url}"
            print(f"🎵 Using recording URL: {recording_url}")
        elif call_log and hasattr(call_log, 'recording_url') and call_log.recording_url:
            # Use recording_url field if available
            recording_url = f"http://192.168.1.17:8000{call_log.recording_url}"
            print(f"🎵 Using recording URL: {recording_url}")
        else:
            # Fallback to the playable_url from Drive
            recording_url = playable_url
            print(f"🎵 Using Drive URL as recording URL: {recording_url}")
        
        comment_text = f"""🔊 Call Recording • {current_time}

Duration: {duration_display} • Speed: 1.0x

🎧 Listen to Recording:

<a href="{recording_url}" target="_blank" style="color: #2fc26e; font-weight: bold; text-decoration: none; border: 1px solid #2fc26e; padding: 8px 12px; border-radius: 4px; display: inline-block; margin: 5px 0;">▶ Play Recording</a>

Call Details:
• Type: {call_type}
• Phone: {phone}
• Duration: {duration} seconds
• Recorded: {current_date}

<a href="{playable_url}" download="call_recording_{current_date}.mp3" style="color: #495057; text-decoration: none; border: 1px solid #6c757d; padding: 6px 10px; border-radius: 3px; font-size: 12px; display: inline-block; margin: 5px 0;">💾 Download Recording</a>

"""
        
        payload = {
            'fields': {
                'ENTITY_ID': int(lead_id),
                'ENTITY_TYPE': 'lead',
                'COMMENT': comment_text
            }
        }
        
        response, result = self._make_bitrix_request(
            f"{self.webhook_url}crm.timeline.comment.add", 
            payload, 
            call_log=call_log,
            sync_type='recording_html_links'
        )
        
        return result.get('result', False)

    def _add_recording_bitrix_disk(self, lead_id, playable_url, call_data, call_log=None, drive_file_id=None):
        """Use Bitrix24 disk file embedding"""
        print(f"🎵 Using Bitrix24 disk embedding")
        
        duration = call_data.get('duration', 0)
        call_type = call_data.get('call_type', 'incoming').title()
        phone = call_data.get('phone_number', '')
        
        duration_minutes = duration / 60.0
        duration_display = f"{duration_minutes:.2f}"
        current_time = timezone.now().strftime('%I:%M %p')
        current_date = timezone.now().strftime('%Y-%m-%d %I:%M %p')
        
        if drive_file_id:
            comment_text = f"""🔊 Call Recording • {current_time}

**Duration:** {duration_display} • **Speed:** 1.0x

[disk file id={drive_file_id}]

**Call Details:**
• **Type:** {call_type}
• **Phone:** {phone}
• **Duration:** {duration} seconds
• **Recorded:** {current_date}

Click the file above to play the recording.
"""
            
            payload = {
                'fields': {
                    'ENTITY_ID': int(lead_id),
                    'ENTITY_TYPE': 'lead',
                    'COMMENT': comment_text,
                    'FILES': [f"disk_{drive_file_id}"]
                }
            }
        else:
            # Fallback to simple links
            comment_text = f"""🔊 Call Recording • {current_time}

**Duration:** {duration_display} • **Speed:** 1.0x

🎧 **Listen to Recording:**

<a href="{playable_url}">▶ Play Recording</a>

**Call Details:**
• **Type:** {call_type}
• **Phone:** {phone}
• **Duration:** {duration} seconds
• **Recorded:** {current_date}
"""
            
            payload = {
                'fields': {
                    'ENTITY_ID': int(lead_id),
                    'ENTITY_TYPE': 'lead',
                    'COMMENT': comment_text
                }
            }
        
        response, result = self._make_bitrix_request(
            f"{self.webhook_url}crm.timeline.comment.add", 
            payload, 
            call_log=call_log,
            sync_type='recording_disk_embed'
        )
        
        return result.get('result', False)

    def _add_recording_simple_links(self, lead_id, playable_url, call_data, call_log=None, drive_file_id=None):
        """Simple text links that always work"""
        print(f"🎵 Creating simple link interface")
        
        duration = call_data.get('duration', 0)
        call_type = call_data.get('call_type', 'incoming').title()
        phone = call_data.get('phone_number', '')
        
        duration_minutes = duration / 60.0
        duration_display = f"{duration_minutes:.2f}"
        current_time = timezone.now().strftime('%I:%M %p')
        current_date = timezone.now().strftime('%Y-%m-%d %I:%M %p')
        
        # Shorten URL for better display
        short_url = playable_url[:80] + "..." if len(playable_url) > 80 else playable_url
        
        comment_text = f"""🔊 Call Recording • {current_time}

**Duration:** {duration_display} • **Speed:** 1.0x

🎧 **Listen to Recording:**

▶ Play Recording: {short_url}

🔊 Listen Now: {short_url}

📱 Mobile Play: {short_url}

**Call Details:**
• **Type:** {call_type}
• **Phone:** {phone}
• **Duration:** {duration} seconds
• **Recorded:** {current_date}

💾 Download: {short_url}
"""
        
        payload = {
            'fields': {
                'ENTITY_ID': int(lead_id),
                'ENTITY_TYPE': 'lead',
                'COMMENT': comment_text
            }
        }
        
        response, result = self._make_bitrix_request(
            f"{self.webhook_url}crm.timeline.comment.add", 
            payload, 
            call_log=call_log,
            sync_type='recording_simple_links'
        )
        
        return result.get('result', False)

    def _add_recording_minimal_player(self, lead_id, playable_url, call_data, call_log=None, drive_file_id=None):
        """HTML5 audio player as fallback"""
        print(f"🎵 Creating HTML5 audio player")
        
        duration = call_data.get('duration', 0)
        call_type = call_data.get('call_type', 'incoming').title()
        phone = call_data.get('phone_number', '')
        
        duration_minutes = duration / 60.0
        duration_display = f"{duration_minutes:.2f}"
        current_time = timezone.now().strftime('%I:%M %p')
        current_date = timezone.now().strftime('%Y-%m-%d %I:%M %p')
        
        comment_text = f"""🔊 Call Recording • {current_time}

**Duration:** {duration_display} • **Speed:** 1.0x

<audio controls style="width: 100%; max-width: 300px; height: 40px;">
    <source src="{playable_url}" type="audio/mpeg">
    Your browser does not support the audio element.
</audio>

**Call Details:**
• **Type:** {call_type}
• **Phone:** {phone}
• **Duration:** {duration} seconds
• **Recorded:** {current_date}

<a href="{playable_url}">💾 Download Recording</a>
"""
        
        payload = {
            'fields': {
                'ENTITY_ID': int(lead_id),
                'ENTITY_TYPE': 'lead',
                'COMMENT': comment_text
            }
        }
        
        response, result = self._make_bitrix_request(
            f"{self.webhook_url}crm.timeline.comment.add", 
            payload, 
            call_log=call_log,
            sync_type='recording_minimal_player'
        )
        
        return result.get('result', False)

    def _add_recording_fallback(self, lead_id, recording_url, call_data, call_log=None):
        """Fallback method with direct URL"""
        print(f"🔗 Using fallback method with direct URL")
        
        call_type = call_data.get('call_type', 'incoming').title()
        duration = call_data.get('duration', 0)
        phone = call_data.get('phone_number', '')
        
        duration_minutes = duration / 60.0
        duration_display = f"{duration_minutes:.2f}"
        current_time = timezone.now().strftime('%I:%M %p')
        
        comment_text = f"""🔊 Call Recording • {current_time}

**Duration:** {duration_display} • **Speed:** 1.0x

🎧 **Recording Available:**

<a href="{recording_url}">▶ Click here to play recording</a>

**Call Details:**
• **Type:** {call_type}
• **Phone:** {phone}
• **Duration:** {duration} seconds

<a href="{recording_url}">💾 Download Recording</a>
"""
        
        payload = {
            'fields': {
                'ENTITY_ID': int(lead_id),
                'ENTITY_TYPE': 'lead',
                'COMMENT': comment_text
            }
        }
        
        response, result = self._make_bitrix_request(
            f"{self.webhook_url}crm.timeline.comment.add", 
            payload, 
            call_log=call_log,
            sync_type='recording_fallback'
        )
        
        return result.get('result', False)

    def upload_file_to_bitrix_drive(self, file_path, filename, call_log=None):
        """Enhanced Drive upload that returns file info with URL"""
        if not self.webhook_url:
            print("❌ No webhook URL configured")
            return None
        
        # Verify file exists
        if not os.path.exists(file_path):
            print(f"❌ File not found: {file_path}")
            return None
        
        # First, try to get or create a dedicated folder for call recordings
        folder_id = self._get_or_create_recordings_folder()
        if not folder_id:
            print("❌ Could not get recordings folder, using root storage")
            folder_id = self.get_bitrix_storage_id()
        
        if not folder_id:
            print("❌ Could not get any storage folder")
            return None
        
        endpoint = f"{self.webhook_url}disk.folder.uploadfile"
        
        try:
            # Read and encode file
            with open(file_path, 'rb') as f:
                file_content = f.read()
                file_size = len(file_content)
                
                if file_size == 0:
                    print(f"❌ File is empty: {file_path}")
                    return None
                
                encoded_content = base64.b64encode(file_content).decode('utf-8')
            
            # Upload to the specific folder
            payload = {
                'id': folder_id,
                'data': {
                    'NAME': filename
                },
                'fileContent': encoded_content,
                'generateUniqueName': True
            }
            
            print(f"📤 Uploading file to Bitrix24 Drive folder {folder_id}: {filename} ({file_size} bytes)")
            
            response, result = self._make_bitrix_request(
                endpoint, payload, timeout=120, call_log=call_log, sync_type='drive_upload'
            )
            
            print(f"📤 Upload response: {response.status_code}")
            
            if result.get('result'):
                file_id = result['result']['ID']
                download_url = result['result'].get('DOWNLOAD_URL', '')
                file_name = result['result'].get('NAME', filename)
                print(f"✅ File uploaded to Bitrix24 Drive. File ID: {file_id}, Name: {file_name}")
                return {
                    'file_id': file_id,
                    'download_url': download_url,
                    'name': file_name,
                    'size': file_size
                }
            else:
                print(f"❌ Failed to upload file to Drive: {result}")
                return None
                
        except Exception as e:
            print(f"❌ Exception uploading file to Drive: {str(e)}")
            return None

    def get_bitrix_storage_id(self):
        """Get the common storage folder ID for file uploads"""
        if not self.webhook_url:
            return None
        
        endpoint = f"{self.webhook_url}disk.storage.getlist"
        
        try:
            response, result = self._make_bitrix_request(endpoint, {})
            
            if result.get('result'):
                storages = result['result']
                # Find common storage
                for storage in storages:
                    if storage.get('ENTITY_TYPE') == 'common':
                        root_folder_id = storage.get('ROOT_OBJECT_ID')
                        print(f"📁 Found Bitrix24 storage root folder: {root_folder_id}")
                        return root_folder_id
                
                # Fallback to first storage's root folder
                if storages:
                    root_folder_id = storages[0].get('ROOT_OBJECT_ID')
                    print(f"📁 Using first storage root folder: {root_folder_id}")
                    return root_folder_id
            
            print("❌ No storage found")
            return None
            
        except Exception as e:
            print(f"❌ Error getting storage ID: {str(e)}")
            return None

    def _get_or_create_recordings_folder(self):
        """Get or create a dedicated folder for call recordings in Drive"""
        if not self.webhook_url:
            return None
        
        folder_name = "Call Recordings"
        storage_id = self.get_bitrix_storage_id()
        
        if not storage_id:
            return None
        
        # First, check if folder already exists
        endpoint = f"{self.webhook_url}disk.folder.getchildren"
        payload = {
            'id': storage_id
        }
        
        try:
            response, result = self._make_bitrix_request(endpoint, payload)
            if result.get('result'):
                for item in result['result']:
                    if item.get('NAME') == folder_name and item.get('TYPE') == 'folder':
                        print(f"📁 Found existing recordings folder: {item['ID']}")
                        return item['ID']
            
            # Folder doesn't exist, create it
            print(f"📁 Creating new recordings folder: {folder_name}")
            endpoint = f"{self.webhook_url}disk.folder.addsubfolder"
            payload = {
                'id': storage_id,
                'data': {
                    'NAME': folder_name
                }
            }
            
            response, result = self._make_bitrix_request(endpoint, payload)
            if result.get('result'):
                new_folder_id = result['result']['ID']
                print(f"✅ Created new recordings folder: {new_folder_id}")
                return new_folder_id
            else:
                print(f"❌ Failed to create recordings folder: {result}")
                return storage_id  # Fallback to root storage
                
        except Exception as e:
            print(f"❌ Error managing recordings folder: {str(e)}")
            return storage_id  # Fallback to root storage

    def register_call(self, call_data, call_log=None):
        """Register call in Bitrix24"""
        if not self.webhook_url:
            print("❌ No webhook URL configured")
            return None
            
        phone_number = call_data.get('phone_number')
        call_type = call_data.get('call_type')
        
        if not phone_number:
            print("❌ No phone number provided in call_data")
            return None
        
        print(f"📞 register_call started for: {phone_number}")
        
        # MAP USER ID TO BITRIX24 USER ID
        django_user_id = call_data.get('staff_id')
        if django_user_id:
            bitrix_user_id = self._map_to_bitrix_user(django_user_id)
        else:
            bitrix_user_id = 1
            print("⚠️ No staff_id provided, using default Bitrix24 user")
        
        print(f"👤 User mapping: {django_user_id} -> {bitrix_user_id}")
        
        # STEP 1: Create or get contact
        contact_id = self.create_or_get_contact(phone_number, call_data.get('caller_name', ''))
        
        # STEP 2: Create or get lead
        lead_id = self.create_or_get_lead(phone_number, call_data.get('caller_name', ''), contact_id)
        
        if not lead_id:
            print("❌ Failed to get/create lead")
            return None
        
        print(f"🎯 Using lead ID: {lead_id} for {phone_number}")
        
        # STEP 3: Register telephony call for POPUP
        endpoint = f"{self.webhook_url}telephony.externalcall.register"
        
        payload = {
            'USER_ID': bitrix_user_id,
            'PHONE_NUMBER': phone_number,
            'TYPE': 1 if call_type == 'incoming' else 2,
            'CALL_START_DATE': call_data.get('start_time', timezone.now().isoformat()),
            'SHOW': 1,
            'CRM_CREATE': 0,
            'LINE_NUMBER': phone_number,
        }
        
        # Add CRM binding to existing entities
        crm_entities = []
        if lead_id:
            crm_entities.append({'ENTITY_ID': lead_id, 'ENTITY_TYPE': 'LEAD'})
        if contact_id:
            crm_entities.append({'ENTITY_ID': contact_id, 'ENTITY_TYPE': 'CONTACT'})
        
        if crm_entities:
            payload['CRM_ENTITY'] = crm_entities
            print(f"🔗 Binding to existing CRM: {crm_entities}")
        
        print(f"🚀 Calling Bitrix24 with payload")
        
        try:
            response, result = self._make_bitrix_request(
                endpoint, payload, call_log=call_log, sync_type='call_register'
            )
            
            print(f"📡 Bitrix24 response status: {response.status_code}")
            
            call_info = None
            if result.get('result'):
                call_info = result['result']
                print(f"✅ Call registered successfully with POPUP")
            else:
                print(f"❌ Bitrix24 registration error: {result}")
                # Try fallback with default user if user error
                if "user" in str(result).lower() and bitrix_user_id != 1:
                    print("🔄 Retrying with default user ID 1...")
                    payload['USER_ID'] = 1
                    response, result = self._make_bitrix_request(endpoint, payload)
                    if result.get('result'):
                        call_info = result['result']
                        print(f"✅ Call registered with default user")
            
            # STEP 4: Add this call to lead's timeline
            if lead_id:
                self.add_call_to_lead_timeline(lead_id, call_data, call_log)
            
            return {
                'call_id': call_info.get('CALL_ID') if call_info else None,
                'lead_id': lead_id,
                'contact_id': contact_id,
                'bitrix_user_id': bitrix_user_id,
                'success': bool(call_info)
            }
            
        except Exception as e:
            print(f"💥 Error registering call: {str(e)}")
            return None

    def finish_call_with_recording_url(self, call_log):
        """Finish call and attach recording URL"""
        if not self.webhook_url or not call_log.bitrix_call_id:
            print("❌ Cannot finish call - missing webhook URL or call ID")
            return False
        
        endpoint = f"{self.webhook_url}telephony.externalcall.finish"
        
        # USE MAPPED BITRIX USER ID
        bitrix_user_id = self._map_to_bitrix_user(call_log.user.id)
        
        payload = {
            'CALL_ID': call_log.bitrix_call_id,
            'USER_ID': bitrix_user_id,
            'DURATION': call_log.duration or 0,
            'STATUS_CODE': 200,
        }
        
        # ADD RECORDING URL IF AVAILABLE
        recording_added = False
        recording_url = None
        
        if call_log.has_recording and call_log.recording_file_exists():
            # Create public URL for the recording file
            recording_url = f"http://192.168.1.17:8000{call_log.recording_url}"
            payload['RECORD_URL'] = recording_url
            recording_added = True
            print(f"🎵 Adding recording URL: {recording_url}")
        else:
            print("📵 No recording found for this call or file doesn't exist")
        
        print(f"🏁 Finishing call at: {endpoint}")
        
        # RETRY LOGIC
        max_retries = 3
        timeout_seconds = 30
        
        for attempt in range(1, max_retries + 1):
            try:
                print(f"🔄 Attempt {attempt}/{max_retries} with {timeout_seconds}s timeout...")
                
                response, result = self._make_bitrix_request(
                    endpoint, payload, timeout=timeout_seconds, 
                    call_log=call_log, sync_type='call_finish'
                )
                
                print(f"🏁 Finish response: {response.status_code}")
                
                if result.get('result'):
                    print(f"✅ Call finished in Bitrix24")
                    
                    # Mark recording as uploaded if it was included
                    if recording_added:
                        call_log.mark_recording_uploaded()
                        print(f"✅ Recording successfully sent to Bitrix24")
                    
                    # Add to timeline with recording link
                    if recording_added and call_log.bitrix_lead_id and recording_url:
                        call_data = call_log.get_bitrix_payload()
                        print(f"🎵 Adding recording to timeline...")
                        self.add_recording_to_lead_timeline(
                            call_log.bitrix_lead_id,
                            recording_url,
                            call_data,
                            call_log
                        )
                    
                    # Mark call as finished
                    call_log.mark_bitrix_finished()
                    return True
                else:
                    error_desc = result.get('error_description', 'Unknown error')
                    print(f"❌ Bitrix24 error: {error_desc}")
                    
                    # If call not found, don't retry
                    if "not found" in error_desc.lower():
                        print(f"❌ Call not registered in Bitrix24, cannot finish")
                        call_log.mark_sync_failed(f"Call not found in Bitrix24: {error_desc}")
                        return False
                    
                    # For user errors, try with default user
                    if "user" in error_desc.lower() and bitrix_user_id != 1:
                        print("🔄 Retrying with default user ID 1...")
                        payload['USER_ID'] = 1
                        continue
                    
                    # For other errors, retry
                    if attempt < max_retries:
                        print(f"⏳ Retrying in 2 seconds...")
                        time.sleep(2)
                        timeout_seconds += 10
                        continue
                    
                    call_log.mark_sync_failed(f"Max retries exceeded: {error_desc}")
                    return False
                    
            except requests.exceptions.Timeout:
                print(f"⏱️ Timeout on attempt {attempt}/{max_retries}")
                
                if attempt < max_retries:
                    print(f"⏳ Retrying with longer timeout...")
                    timeout_seconds += 15
                    time.sleep(2)
                    continue
                
                call_log.mark_sync_failed("All retry attempts failed due to timeout")
                return False
                
            except Exception as e:
                print(f"🏁 Exception finishing call: {str(e)}")
                
                if attempt < max_retries:
                    print(f"⏳ Retrying after exception...")
                    time.sleep(2)
                    continue
                
                call_log.mark_sync_failed(f"Exception: {str(e)}")
                return False
        
        return False

    def process_call_completion(self, call_log):
        """Complete workflow for call completion with recording"""
        print(f"🔄 Processing call completion for call {call_log.id}")
        
        # Validate call can be processed
        validation_errors = call_log.validate_for_bitrix_upload()
        if validation_errors:
            print(f"❌ Call validation failed: {validation_errors}")
            call_log.mark_sync_failed(f"Validation errors: {', '.join(validation_errors)}")
            return False
        
        # Step 1: Register call if not already registered
        if not call_log.bitrix_call_id:
            print("📞 Call not registered in Bitrix24, registering now...")
            call_data = call_log.get_bitrix_payload()
            bitrix_result = self.register_call(call_data, call_log)
            
            if bitrix_result and bitrix_result.get('success'):
                call_log.mark_bitrix_registered(
                    bitrix_result['call_id'],
                    bitrix_result['lead_id'],
                    bitrix_result['contact_id'],
                    bitrix_result.get('bitrix_user_id')
                )
                print(f"✅ Call registered in Bitrix24")
            else:
                print(f"❌ Failed to register call in Bitrix24")
                call_log.mark_sync_failed("Failed to register call")
                return False
        
        # Step 2: Finish call with recording
        if call_log.bitrix_call_id:
            print("🏁 Finishing call in Bitrix24 with recording...")
            success = self.finish_call_with_recording_url(call_log)
            
            if success:
                print(f"✅ Call completion processed successfully")
                return True
            else:
                print(f"❌ Failed to finish call in Bitrix24")
                return False
        
        return False

    def test_connection(self):
        """Test Bitrix24 connection and permissions"""
        if not self.webhook_url:
            return {'success': False, 'error': 'No webhook URL configured'}
        
        try:
            # Test user access
            users = self.get_bitrix_users()
            if users:
                return {
                    'success': True,
                    'message': 'Connection successful',
                    'users_count': len(users),
                    'webhook_url': self.webhook_url
                }
            else:
                return {
                    'success': False,
                    'error': 'Could not fetch users - check permissions'
                }
        except Exception as e:
            return {
                'success': False,
                'error': f'Connection test failed: {str(e)}'
            }

    def debug_file_locations(self, lead_id):
        """Debug method to find where files are stored in Bitrix24"""
        if not self.webhook_url:
            return
        
        print(f"🔍 Debugging file locations for lead {lead_id}")
        
        # 1. Check timeline comments for attachments
        endpoint = f"{self.webhook_url}crm.timeline.comment.list"
        payload = {
            'filter': {'ENTITY_ID': lead_id, 'ENTITY_TYPE': 'lead'},
            'select': ['ID', 'COMMENT', 'FILES']
        }
        
        try:
            response, result = self._make_bitrix_request(endpoint, payload)
            if result.get('result'):
                for comment in result['result']:
                    if 'FILES' in comment and comment['FILES']:
                        print(f"📎 Found attached files in timeline comment {comment['ID']}:")
                        for file in comment['FILES']:
                            print(f"   - File: {file}")
        except Exception as e:
            print(f"❌ Error checking timeline: {str(e)}")