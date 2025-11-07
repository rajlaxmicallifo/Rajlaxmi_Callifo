from django.db import models
from django.contrib.auth.models import User
from django.utils import timezone
import os

class CallLog(models.Model):
    CALL_TYPES = [
        ('incoming', 'Incoming'),
        ('outgoing', 'Outgoing'),
        ('missed', 'Missed'),
    ]
    
    CALL_STATUS = [
        ('registered', 'Registered in Bitrix24'),
        ('completed', 'Completed'),
        ('failed', 'Failed'),
        ('recording_uploaded', 'Recording Uploaded'),
    ]
    
    # Required fields
    phone_number = models.CharField(max_length=20)
    call_type = models.CharField(max_length=10, choices=CALL_TYPES)
    duration = models.IntegerField(default=0)
    timestamp = models.DateTimeField(auto_now_add=True)
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    
    # Optional fields
    notes = models.TextField(blank=True, null=True)
    
    # Recording fields
    recording = models.FileField(
        upload_to='call_recordings/%Y/%m/%d/',
        blank=True, 
        null=True,
        max_length=500,
        verbose_name="Call Recording File"
    )
    
    # ✅ ENHANCED: Better tracking for Bitrix24 upload status
    recording_uploaded_to_bitrix = models.BooleanField(
        default=False,
        verbose_name="Recording uploaded to Bitrix24"
    )
    
    recording_uploaded_at = models.DateTimeField(
        blank=True, 
        null=True,
        verbose_name="Recording upload timestamp"
    )
    
    # Bitrix24 integration fields
    bitrix_call_id = models.CharField(max_length=200, blank=True, null=True)
    bitrix_lead_id = models.BigIntegerField(blank=True, null=True)
    bitrix_contact_id = models.BigIntegerField(blank=True, null=True)
    bitrix_synced = models.BooleanField(default=False)
    
    # 🆕 ENHANCED BITRIX24 TRACKING
    bitrix_user_id = models.IntegerField(
        blank=True, 
        null=True,
        verbose_name="Bitrix24 User ID used for this call"
    )
    
    call_status = models.CharField(
        max_length=20,
        choices=CALL_STATUS,
        default='registered',
        verbose_name="Call synchronization status"
    )
    
    bitrix_registered_at = models.DateTimeField(
        blank=True, 
        null=True,
        verbose_name="Bitrix24 registration timestamp"
    )
    
    bitrix_finished_at = models.DateTimeField(
        blank=True, 
        null=True,
        verbose_name="Bitrix24 finish timestamp"
    )
    
    error_message = models.TextField(
        blank=True, 
        null=True,
        verbose_name="Error details if sync failed"
    )
    
    # 🆕 CALL METADATA FOR BETTER TRACKING
    caller_name = models.CharField(
        max_length=255, 
        blank=True, 
        null=True,
        verbose_name="Caller name from contacts"
    )
    
    start_time = models.DateTimeField(
        default=timezone.now,
        verbose_name="Call start time"
    )
    
    end_time = models.DateTimeField(
        blank=True, 
        null=True,
        verbose_name="Call end time"
    )
    
    is_answered = models.BooleanField(
        default=False,
        verbose_name="Call was answered"
    )
    
    recording_duration = models.IntegerField(
        default=0,
        verbose_name="Actual recording duration in seconds"
    )
    
    def __str__(self):
        status_icon = "🎵" if self.has_recording else "📞"
        return f"{status_icon} {self.call_type} - {self.phone_number} - {self.timestamp.strftime('%Y-%m-%d %H:%M')}"
    
    # 🔄 ENHANCED PROPERTIES FOR EASY ACCESS
    @property
    def has_recording(self):
        """Check if call has a recording file"""
        return bool(self.recording and self.recording.name)
    
    @property
    def recording_filename(self):
        """Get just the filename without path"""
        if self.recording and self.recording.name:
            return os.path.basename(self.recording.name)
        return None
    
    @property
    def recording_url(self):
        """Get the full URL to access the recording"""
        if self.recording and self.recording.name:
            return self.recording.url
        return None
    
    @property
    def recording_size(self):
        """Get recording file size in human-readable format"""
        try:
            if self.recording and hasattr(self.recording, 'size') and self.recording.size:
                size = self.recording.size
                if size < 1024:
                    return f"{size} B"
                elif size < 1024 * 1024:
                    return f"{size / 1024:.1f} KB"
                else:
                    return f"{size / (1024 * 1024):.1f} MB"
        except (ValueError, OSError):
            pass
        return "Unknown"
    
    @property
    def recording_file_extension(self):
        """Get recording file extension"""
        if self.recording and self.recording.name:
            return os.path.splitext(self.recording.name)[1].lower()
        return None
    
    @property
    def is_recording_uploaded(self):
        """Check if recording is uploaded to Bitrix24"""
        return self.recording_uploaded_to_bitrix
    
    @property
    def bitrix_lead_url(self):
        """Generate Bitrix24 lead URL"""
        if self.bitrix_lead_id:
            return f"https://world.bitrix24.com/CRM/lead/details/{self.bitrix_lead_id}/"
        return None
    
    @property
    def bitrix_contact_url(self):
        """Generate Bitrix24 contact URL"""
        if self.bitrix_contact_id:
            return f"https://world.bitrix24.com/CRM/contact/details/{self.bitrix_contact_id}/"
        return None
    
    @property
    def call_duration_formatted(self):
        """Format duration in MM:SS format"""
        minutes = self.duration // 60
        seconds = self.duration % 60
        return f"{minutes:02d}:{seconds:02d}"
    
    @property
    def recording_duration_formatted(self):
        """Format recording duration in MM:SS format"""
        minutes = self.recording_duration // 60
        seconds = self.recording_duration % 60
        return f"{minutes:02d}:{seconds:02d}"
    
    @property
    def can_upload_to_bitrix(self):
        """Check if this call can be uploaded to Bitrix24"""
        return (self.has_recording and 
                not self.recording_uploaded_to_bitrix and 
                self.duration > 0 and
                self.is_answered)
    
    @property
    def sync_status_icon(self):
        """Get status icon for display"""
        icons = {
            'registered': '📞',
            'completed': '✅',
            'failed': '❌',
            'recording_uploaded': '🎵',
        }
        return icons.get(self.call_status, '📞')
    
    @property
    def sync_status_text(self):
        """Get human-readable sync status"""
        status_text = {
            'registered': 'Registered in Bitrix24',
            'completed': 'Call completed',
            'failed': 'Sync failed',
            'recording_uploaded': 'Recording uploaded to Bitrix24',
        }
        return status_text.get(self.call_status, 'Unknown')
    
    # 🆕 METHODS FOR BITRIX24 INTEGRATION
    def mark_bitrix_registered(self, call_id, lead_id, contact_id, user_id=None):
        """Mark call as registered in Bitrix24"""
        self.bitrix_call_id = call_id
        self.bitrix_lead_id = lead_id
        self.bitrix_contact_id = contact_id
        self.bitrix_synced = True
        self.bitrix_registered_at = timezone.now()
        self.call_status = 'registered'
        
        if user_id:
            self.bitrix_user_id = user_id
            
        self.save()
        print(f"✅ Call {self.id} marked as registered in Bitrix24")
    
    def mark_bitrix_finished(self):
        """Mark call as finished in Bitrix24"""
        self.bitrix_finished_at = timezone.now()
        self.call_status = 'completed'
        self.save()
        print(f"✅ Call {self.id} marked as finished in Bitrix24")
    
    def mark_recording_uploaded(self):
        """Mark recording as uploaded to Bitrix24"""
        self.recording_uploaded_to_bitrix = True
        self.recording_uploaded_at = timezone.now()
        self.call_status = 'recording_uploaded'
        self.save()
        print(f"✅ Recording for call {self.id} marked as uploaded to Bitrix24")
    
    def mark_sync_failed(self, error_message):
        """Mark Bitrix24 sync as failed"""
        self.call_status = 'failed'
        self.error_message = error_message
        self.save()
        print(f"❌ Call {self.id} sync failed: {error_message}")
    
    def get_bitrix_payload(self):
        """Generate payload for Bitrix24 API"""
        return {
            'phone_number': self.phone_number,
            'call_type': self.call_type,
            'duration': self.duration,
            'start_time': self.start_time.isoformat(),
            'staff_id': self.bitrix_user_id or 1,  # Default to user 1
            'caller_name': self.caller_name or '',
            'call_id': str(self.id),
        }
    
    def validate_for_bitrix_upload(self):
        """Validate if call can be uploaded to Bitrix24"""
        errors = []
        
        if not self.phone_number:
            errors.append("Phone number is required")
        
        if self.duration <= 0:
            errors.append("Call duration must be positive")
        
        if not self.is_answered:
            errors.append("Call must be answered to upload recording")
        
        if not self.has_recording:
            errors.append("Recording file is required")
        
        return errors
    
    # 🆕 FILE MANAGEMENT METHODS
    def get_recording_file_path(self):
        """Get absolute file path to recording"""
        if self.recording and self.recording.name:
            return self.recording.path
        return None
    
    def recording_file_exists(self):
        """Check if recording file actually exists on disk"""
        try:
            file_path = self.get_recording_file_path()
            return file_path and os.path.exists(file_path)
        except (ValueError, OSError):
            return False
    
    def get_recording_file_size(self):
        """Get actual file size in bytes"""
        try:
            file_path = self.get_recording_file_path()
            if file_path and os.path.exists(file_path):
                return os.path.getsize(file_path)
        except (ValueError, OSError):
            pass
        return 0
    
    def delete_recording_file(self):
        """Delete the recording file from storage"""
        try:
            if self.recording and self.recording.name:
                # Delete the file from storage
                self.recording.delete(save=False)
                # Clear the field
                self.recording = None
                self.recording_uploaded_to_bitrix = False
                self.recording_uploaded_at = None
                self.save()
                print(f"🗑️ Recording file deleted for call {self.id}")
                return True
        except Exception as e:
            print(f"❌ Error deleting recording file: {e}")
        return False
    
    class Meta:
        ordering = ['-timestamp']
        verbose_name = "Call Log"
        verbose_name_plural = "Call Logs"
        indexes = [
            models.Index(fields=['phone_number']),
            models.Index(fields=['timestamp']),
            models.Index(fields=['call_type']),
            models.Index(fields=['user', 'timestamp']),
            models.Index(fields=['bitrix_lead_id']),
            models.Index(fields=['recording_uploaded_to_bitrix']),
        ]
        constraints = [
            models.CheckConstraint(
                check=models.Q(duration__gte=0),
                name="call_duration_positive"
            ),
        ]


# 🆕 ADDITIONAL MODEL FOR BITRIX24 USER MAPPING
class Bitrix24UserMapping(models.Model):
    """Map Django users to Bitrix24 users"""
    django_user = models.OneToOneField(
        User, 
        on_delete=models.CASCADE,
        related_name='bitrix_mapping'
    )
    bitrix_user_id = models.IntegerField(verbose_name="Bitrix24 User ID")
    bitrix_user_name = models.CharField(
        max_length=255, 
        blank=True,
        verbose_name="Bitrix24 User Name"
    )
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.django_user.username} -> Bitrix24 User {self.bitrix_user_id}"

    class Meta:
        verbose_name = "Bitrix24 User Mapping"
        verbose_name_plural = "Bitrix24 User Mappings"


# 🆕 MODEL FOR SYNC LOGS
class Bitrix24SyncLog(models.Model):
    """Log Bitrix24 synchronization attempts"""
    SYNC_TYPES = [
        ('call_register', 'Call Registration'),
        ('call_finish', 'Call Finish'),
        ('recording_upload', 'Recording Upload'),
        ('lead_update', 'Lead Update'),
    ]
    
    STATUS_CHOICES = [
        ('success', 'Success'),
        ('failed', 'Failed'),
        ('partial', 'Partial Success'),
    ]
    
    call_log = models.ForeignKey(
        CallLog, 
        on_delete=models.CASCADE,
        related_name='sync_logs',
        blank=True,
        null=True
    )
    sync_type = models.CharField(max_length=20, choices=SYNC_TYPES)
    status = models.CharField(max_length=10, choices=STATUS_CHOICES)
    request_payload = models.JSONField(blank=True, null=True)
    response_data = models.JSONField(blank=True, null=True)
    error_message = models.TextField(blank=True, null=True)
    duration_ms = models.IntegerField(default=0, verbose_name="API call duration in milliseconds")
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.sync_type} - {self.status} - {self.created_at}"

    class Meta:
        ordering = ['-created_at']
        verbose_name = "Bitrix24 Sync Log"
        verbose_name_plural = "Bitrix24 Sync Logs"