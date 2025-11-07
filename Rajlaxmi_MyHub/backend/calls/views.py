from rest_framework import generics, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.utils import timezone
from datetime import datetime
from .models import CallLog, Bitrix24UserMapping
from .serializers import CallLogSerializer
from .services.bitrix24_service import Bitrix24Service
import logging
import os

logger = logging.getLogger(__name__)

class CallLogCreateView(generics.CreateAPIView):
    """
    API view to create a CallLog with Bitrix24 integration.
    Only authenticated users can post, and the 'user' field
    is automatically set to the logged-in user.
    """
    queryset = CallLog.objects.all()
    serializer_class = CallLogSerializer
    permission_classes = [IsAuthenticated]





    













    def perform_create(self, serializer):
        # Save the call log with the authenticated user
        call_log = serializer.save(user=self.request.user)
        
        # Integrate with Bitrix24 for all calls (incoming AND outgoing)
        self.register_call_with_bitrix24(call_log)
    
    def register_call_with_bitrix24(self, call_log):
        """Register call with Bitrix24 and show caller ID popup"""
        try:
            bitrix_service = Bitrix24Service()
            
            call_data = {
                'phone_number': call_log.phone_number,
                'call_type': call_log.call_type,
                'start_time': call_log.timestamp.isoformat(),
                'staff_id': call_log.user.id,
                'caller_name': getattr(call_log, 'caller_name', ''),
            }
            
            bitrix_result = bitrix_service.register_call(call_data, call_log)
            
            if bitrix_result and bitrix_result.get('success'):
                # Update call log with Bitrix24 data
                call_id = bitrix_result.get('call_id')
                lead_id = bitrix_result.get('lead_id')
                contact_id = bitrix_result.get('contact_id')
                bitrix_user_id = bitrix_result.get('bitrix_user_id')
                
                # Update call log with Bitrix24 data
                if call_id:
                    call_log.bitrix_call_id = str(call_id)[:95]
                
                if lead_id:
                    call_log.bitrix_lead_id = int(lead_id)
                    print(f"📝 Linked to lead: {lead_id}")
                
                if contact_id:
                    call_log.bitrix_contact_id = int(contact_id)
                
                if bitrix_user_id:
                    call_log.bitrix_user_id = bitrix_user_id
                
                call_log.bitrix_synced = True
                call_log.bitrix_registered_at = timezone.now()
                call_log.call_status = 'registered'
                call_log.save()
                
                logger.info(f"Call {call_log.id} registered with Bitrix24. Lead: {call_log.bitrix_lead_id}, Call ID: {call_log.bitrix_call_id}")
            else:
                logger.error(f"Failed to register call {call_log.id} with Bitrix24")
                call_log.mark_sync_failed("Failed to register with Bitrix24")
                
        except Exception as e:
            logger.error(f"Error registering call with Bitrix24: {str(e)}")
            call_log.mark_sync_failed(f"Registration error: {str(e)}")

class CallLogListView(generics.ListAPIView):
    """
    API view to list CallLogs for the authenticated user.
    """
    serializer_class = CallLogSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return CallLog.objects.filter(user=self.request.user).order_by('-timestamp')

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def save_call_log(request):
    """Function-based API view to create a CallLog with Bitrix24 integration and recording support."""
    
    print(f"🔥 Received call data: {request.data}")
    print(f"👤 Authenticated user: {request.user} (ID: {request.user.id})")
    print(f"📁 Files received: {request.FILES}")
    
    try:
        # Extract data from request
        caller_number = request.data.get('caller_number') or request.data.get('phone_number')
        call_type = request.data.get('call_type')
        start_time_str = request.data.get('start_time')
        # FIX: Convert duration to integer
        duration = int(request.data.get('duration', 0))
        caller_name = request.data.get('caller_name', '')
        notes = request.data.get('notes', '')
        call_id = request.data.get('call_id')  # 🆕 Get call_id from request
        
        print(f"📞 Processing call: {caller_number}, type: {call_type}, user: {request.user.id}, duration: {duration}")
        
        # Validate required fields
        if not caller_number:
            return Response({'error': 'Missing phone_number/caller_number field'}, status=status.HTTP_400_BAD_REQUEST)
            
        if not call_type:
            return Response({'error': 'Missing call_type field'}, status=status.HTTP_400_BAD_REQUEST)

        # Handle start_time
        if start_time_str:
            try:
                start_time = datetime.fromisoformat(start_time_str.replace('Z', '+00:00'))
            except ValueError as e:
                print(f"❌ Invalid datetime: {e}")
                start_time = timezone.now()
        else:
            start_time = timezone.now()

        # Use the authenticated user
        staff_user = request.user

        # 🆕 CHECK FOR EXISTING CALL LOG
        existing_call = None
        if call_id:
            try:
                existing_call = CallLog.objects.get(
                    user=staff_user,
                    phone_number=caller_number,
                    call_type=call_type,
                    timestamp__date=start_time.date()
                )
                print(f"🔄 Found existing call log: {existing_call.id}")
            except CallLog.DoesNotExist:
                pass
            except CallLog.MultipleObjectsReturned:
                # Get the most recent one
                existing_call = CallLog.objects.filter(
                    user=staff_user,
                    phone_number=caller_number,
                    call_type=call_type,
                    timestamp__date=start_time.date()
                ).order_by('-timestamp').first()
                print(f"🔄 Found multiple existing calls, using most recent: {existing_call.id}")

        # Create or update call log
        if existing_call:
            call_log = existing_call
            call_log.duration = duration
            call_log.notes = notes
            call_log.end_time = timezone.now()
            call_log.is_answered = True
            print(f"🔄 Updated existing call log: {call_log.id}")
        else:
            call_log = CallLog.objects.create(
                phone_number=caller_number,
                call_type=call_type,
                timestamp=start_time,
                duration=duration,
                user=staff_user,
                notes=notes,
                recording_uploaded_to_bitrix=False,
                is_answered=True,
                end_time=timezone.now(),
                caller_name=caller_name,
            )
            print(f"💾 Created new call log ID: {call_log.id} for user: {staff_user.id}")

        # Handle recording file upload
        recording_file = request.FILES.get('recording')
        recording_uploaded = False
        recording_url = None
        
        if recording_file:
            print(f"🎵 Processing recording file: {recording_file.name}")
            
            # Validate file size and type
            if recording_file.size > 100 * 1024 * 1024:
                return Response({'error': 'Recording file too large (max 100MB)'}, status=status.HTTP_400_BAD_REQUEST)
            
            allowed_types = ['.mp3']
            file_ext = os.path.splitext(recording_file.name)[1].lower()
            if file_ext not in allowed_types:
                return Response({'error': f'Invalid file type. Allowed: {allowed_types}'}, status=status.HTTP_400_BAD_REQUEST)
                
            try:
                unique_filename = f'recording_{call_log.id}_{int(timezone.now().timestamp())}{file_ext}'
                call_log.recording.save(unique_filename, recording_file)
                call_log.recording_duration = duration
                call_log.save()
                recording_uploaded = True
                recording_url = call_log.recording.url
                print(f"✅ Recording saved successfully at: {recording_url}")
            except Exception as file_error:
                print(f"❌ Error saving recording file: {str(file_error)}")
                return Response({'error': f'Failed to save recording: {str(file_error)}'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        else:
            print("ℹ️ No recording file provided")

        # 🆕 ENHANCED BITRIX24 INTEGRATION
        print(f"📲 Processing call for Bitrix24...")
        
        try:
            bitrix_service = Bitrix24Service()
            
            call_data = {
                'phone_number': caller_number,
                'call_type': call_type,
                'start_time': start_time.isoformat(),
                'staff_id': staff_user.id,
                'caller_name': caller_name,
                'duration': duration,
            }
            
            # 🆕 REGISTER CALL WITH BITRIX24
            bitrix_result = bitrix_service.register_call(call_data, call_log)
            
            if bitrix_result and bitrix_result.get('success'):
                try:
                    call_id = bitrix_result.get('call_id')
                    lead_id = bitrix_result.get('lead_id')
                    contact_id = bitrix_result.get('contact_id')
                    bitrix_user_id = bitrix_result.get('bitrix_user_id')
                    
                    # 🆕 UPDATE CALL LOG WITH BITRIX24 DATA
                    if call_id:
                        call_log.bitrix_call_id = str(call_id)[:95]
                        print(f"✅ Saved bitrix_call_id: {call_log.bitrix_call_id}")
                    
                    if lead_id:
                        call_log.bitrix_lead_id = int(lead_id)
                        print(f"✅ Saved bitrix_lead_id: {call_log.bitrix_lead_id}")
                    
                    if contact_id:
                        call_log.bitrix_contact_id = int(contact_id)
                        print(f"✅ Saved bitrix_contact_id: {call_log.bitrix_contact_id}")
                    
                    if bitrix_user_id:
                        call_log.bitrix_user_id = bitrix_user_id
                    
                    call_log.bitrix_synced = True
                    call_log.bitrix_registered_at = timezone.now()
                    call_log.call_status = 'registered'
                    call_log.save()
                    
                    print(f"✅ Successfully saved call log. Lead ID: {call_log.bitrix_lead_id}")
                    
                    # 🆕 PROCESS CALL COMPLETION WITH RECORDING
                    if call_log.can_upload_to_bitrix:
                        print(f"🎵 Call has recording and duration > 0, processing completion...")
                        print(f"🎵 Duration: {duration}, Recording: {recording_uploaded}, Call ID: {call_log.bitrix_call_id}")
                        
                        try:
                            # 🆕 USE ENHANCED PROCESSING METHOD
                            process_success = bitrix_service.process_call_completion(call_log)
                            if process_success:
                                print(f"✅ Call completion processed successfully with recording")
                                call_log.mark_bitrix_finished()
                            else:
                                print(f"❌ Failed to process call completion")
                                call_log.mark_sync_failed("Failed to process call completion")
                                
                        except Exception as process_error:
                            print(f"❌ Error processing call completion: {str(process_error)}")
                            call_log.mark_sync_failed(f"Process error: {str(process_error)}")
                            import traceback
                            traceback.print_exc()
                    else:
                        print(f"⚠️ Skipping call completion: can_upload={call_log.can_upload_to_bitrix}")
                    
                except Exception as save_error:
                    print(f"💾 Error saving Bitrix24 data: {str(save_error)}")
                    call_log.mark_sync_failed(f"Save error: {str(save_error)}")
                    import traceback
                    traceback.print_exc()
            else:
                print(f"❌ No successful result from Bitrix24")
                call_log.mark_sync_failed("Bitrix24 registration failed")
                
        except Exception as bitrix_error:
            print(f"💥 Bitrix24 error: {str(bitrix_error)}")
            call_log.mark_sync_failed(f"Bitrix24 error: {str(bitrix_error)}")
            import traceback
            traceback.print_exc()

        return Response({
            'success': True, 
            'call_id': call_log.id,
            'user_id': staff_user.id,
            'bitrix_lead_id': getattr(call_log, 'bitrix_lead_id', None),
            'bitrix_call_id': getattr(call_log, 'bitrix_call_id', None),
            'recording_uploaded': recording_uploaded,
            'recording_url': recording_url,
            'recording_uploaded_to_bitrix': getattr(call_log, 'recording_uploaded_to_bitrix', False),
            'call_status': getattr(call_log, 'call_status', 'unknown'),
            'message': 'Call log saved successfully'
        }, status=status.HTTP_201_CREATED)
        
    except Exception as e:
        print(f"💥 General error: {str(e)}")
        logger.error(f"Error in save_call_log: {str(e)}")
        import traceback
        traceback.print_exc()
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)







    





@api_view(['POST'])
@permission_classes([IsAuthenticated])
def register_incoming_call_immediately(request):
    """Register incoming call immediately for real-time popup - ENHANCED"""
    try:
        phone_number = request.data.get('phone_number') or request.data.get('caller_number')
        caller_name = request.data.get('caller_name', '')
        
        if not phone_number:
            return Response({'error': 'phone_number required'}, status=status.HTTP_400_BAD_REQUEST)
        
        print(f"🔔 IMMEDIATE incoming call registration: {phone_number}")
        
        # 🆕 CREATE CALL LOG FIRST
        call_log = CallLog.objects.create(
            phone_number=phone_number,
            call_type='incoming',
            timestamp=timezone.now(),
            user=request.user,
            caller_name=caller_name,
            is_answered=True,
            start_time=timezone.now()
        )
        
        print(f"💾 Created call log ID: {call_log.id}")
        
        bitrix_service = Bitrix24Service()
        
        call_data = {
            'phone_number': phone_number,
            'call_type': 'incoming',
            'start_time': timezone.now().isoformat(),
            'staff_id': request.user.id,
            'caller_name': caller_name,
        }
        
        # This should trigger the popup immediately
        bitrix_result = bitrix_service.register_call(call_data, call_log)
        
        if bitrix_result and bitrix_result.get('success'):
            call_id = bitrix_result.get('call_id')
            lead_id = bitrix_result.get('lead_id')
            
            # 🆕 UPDATE CALL LOG WITH BITRIX24 DATA
            if call_id:
                call_log.bitrix_call_id = str(call_id)[:95]
            if lead_id:
                call_log.bitrix_lead_id = int(lead_id)
            
            call_log.bitrix_synced = True
            call_log.bitrix_registered_at = timezone.now()
            call_log.call_status = 'registered'
            call_log.save()
                
            return Response({
                'success': True,
                'call_id': call_log.id,  # 🆕 RETURN LOCAL CALL ID
                'bitrix_call_id': call_id,
                'bitrix_lead_id': lead_id,
                'popup_triggered': True,
                'message': 'Call registered for popup'
            })
        else:
            return Response({
                'success': False,
                'popup_triggered': False,
                'message': 'Failed to register call for popup'
            })
            
    except Exception as e:
        print(f"💥 Error in immediate call registration: {str(e)}")
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)



@api_view(['POST'])
@permission_classes([IsAuthenticated])
def finish_call(request):
    """API view to finish a call and update Bitrix24."""
    try:
        call_id = request.data.get('call_id')
        duration = int(request.data.get('duration', 0))
        call_status = request.data.get('status', 'completed')
        notes = request.data.get('notes', '')
        
        if not call_id:
            return Response({'error': 'call_id is required'}, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            call_log = CallLog.objects.get(id=call_id, user=request.user)
        except CallLog.DoesNotExist:
            return Response({'error': 'Call not found'}, status=status.HTTP_404_NOT_FOUND)
        
        # Update call log with end data
        call_log.duration = duration
        call_log.notes = notes
        call_log.end_time = timezone.now()
        call_log.is_answered = True
        call_log.save()
        
        # 🆕 ENHANCED BITRIX24 FINISHING
        if hasattr(call_log, 'bitrix_call_id') and call_log.bitrix_call_id:
            try:
                bitrix_service = Bitrix24Service()
                
                # 🆕 USE ENHANCED PROCESSING METHOD
                if call_log.can_upload_to_bitrix:
                    success = bitrix_service.process_call_completion(call_log)
                    print(f"🎵 Processed call completion with recording")
                else:
                    # Use normal method for calls without recording
                    success = bitrix_service.finish_call_with_recording_url(call_log)
                    print(f"📞 Finished call without recording")
                
                if success:
                    logger.info(f"Call {call_log.id} finished in Bitrix24. Lead: {call_log.bitrix_lead_id}")
                    call_log.mark_bitrix_finished()
                else:
                    logger.error(f"Failed to finish call {call_log.id} in Bitrix24")
                    call_log.mark_sync_failed("Failed to finish call")
                    
            except Exception as e:
                logger.error(f"Error finishing call in Bitrix24: {str(e)}")
                call_log.mark_sync_failed(f"Finish error: {str(e)}")
        
        return Response({
            'success': True,
            'message': 'Call finished successfully',
            'call_id': call_log.id,
            'bitrix_lead_id': getattr(call_log, 'bitrix_lead_id', None),
            'recording_uploaded_to_bitrix': getattr(call_log, 'recording_uploaded_to_bitrix', False),
            'call_status': getattr(call_log, 'call_status', 'unknown')
        })
        
    except Exception as e:
        logger.error(f"Error in finish_call: {str(e)}")
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def upload_recording_to_bitrix(request, call_id):
    """🆕 API view to manually upload recording to Bitrix24 Drive"""
    try:
        call_log = CallLog.objects.get(id=call_id, user=request.user)
        
        if not call_log.has_recording:
            return Response({'error': 'Call has no recording'}, status=status.HTTP_400_BAD_REQUEST)
        
        if call_log.recording_uploaded_to_bitrix:
            return Response({'error': 'Recording already uploaded to Bitrix24'}, status=status.HTTP_400_BAD_REQUEST)
        
        if not call_log.bitrix_lead_id:
            return Response({'error': 'Call not linked to Bitrix24 lead'}, status=status.HTTP_400_BAD_REQUEST)
        
        print(f"🎵 Starting manual Bitrix24 Drive upload for call {call_id}")
        
        bitrix_service = Bitrix24Service()
        success = bitrix_service.upload_recording_to_bitrix_drive(call_log)
        
        if success:
            return Response({
                'success': True,
                'message': 'Recording uploaded to Bitrix24 Drive successfully',
                'call_id': call_log.id,
                'bitrix_lead_id': call_log.bitrix_lead_id
            })
        else:
            return Response({
                'success': False,
                'message': 'Failed to upload recording to Bitrix24 Drive',
                'call_id': call_log.id
            })
            
    except CallLog.DoesNotExist:
        return Response({'error': 'Call not found'}, status=status.HTTP_404_NOT_FOUND)
    except Exception as e:
        logger.error(f"Error uploading recording to Bitrix24: {str(e)}")
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def finish_call_with_recording(request):
    """API view to finish a call and upload recording to Bitrix24 - NEW ENDPOINT"""
    try:
        call_id = request.data.get('call_id')
        duration = request.data.get('duration', 0)
        
        if not call_id:
            return Response({'error': 'call_id is required'}, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            call_log = CallLog.objects.get(id=call_id, user=request.user)
        except CallLog.DoesNotExist:
            return Response({'error': 'Call not found'}, status=status.HTTP_404_NOT_FOUND)
        
        # Handle recording file upload
        recording_file = request.FILES.get('recording')
        recording_uploaded = False
        
        if recording_file:
            print(f"🎵 Processing recording file for finished call: {recording_file.name}")
            
            # Validate file
            if recording_file.size > 100 * 1024 * 1024:
                return Response({'error': 'Recording file too large (max 100MB)'}, status=status.HTTP_400_BAD_REQUEST)
            
            allowed_types = ['.mp3', '.wav', '.m4a', '.aac', '.mp4', '.3gp', '.amr']
            file_ext = os.path.splitext(recording_file.name)[1].lower()
            if file_ext not in allowed_types:
                return Response({'error': f'Invalid file type. Allowed: {allowed_types}'}, status=status.HTTP_400_BAD_REQUEST)
            
            try:
                unique_filename = f'recording_{call_log.id}_{int(timezone.now().timestamp())}{file_ext}'
                call_log.recording.save(unique_filename, recording_file)
                call_log.recording_duration = duration
                recording_uploaded = True
                print(f"✅ Recording uploaded for call {call_id}")
            except Exception as file_error:
                return Response({'error': f'Failed to save recording: {str(file_error)}'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        
        # Update call log
        call_log.duration = duration
        call_log.end_time = timezone.now()
        call_log.is_answered = True
        call_log.save()
        
        # 🆕 ENHANCED BITRIX24 PROCESSING
        if call_log.bitrix_call_id:
            try:
                bitrix_service = Bitrix24Service()
                
                # 🆕 USE ENHANCED PROCESSING METHOD
                success = bitrix_service.process_call_completion(call_log)
                
                if success:
                    logger.info(f"Call {call_log.id} finished with recording in Bitrix24")
                    return Response({
                        'success': True,
                        'message': 'Call finished with recording successfully',
                        'call_id': call_log.id,
                        'recording_uploaded': recording_uploaded,
                        'recording_uploaded_to_bitrix': call_log.recording_uploaded_to_bitrix,
                        'bitrix_lead_id': call_log.bitrix_lead_id,
                        'call_status': call_log.call_status
                    })
                else:
                    return Response({
                        'success': False,
                        'message': 'Failed to finish call with recording in Bitrix24',
                        'call_id': call_log.id
                    })
                    
            except Exception as e:
                logger.error(f"Error finishing call with recording: {str(e)}")
                return Response({
                    'error': f'Error finishing call: {str(e)}',
                    'call_id': call_log.id
                }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        else:
            return Response({
                'error': 'Call not registered with Bitrix24',
                'call_id': call_log.id
            }, status=status.HTTP_400_BAD_REQUEST)
        
    except Exception as e:
        logger.error(f"Error in finish_call_with_recording: {str(e)}")
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def bitrix_call_stats(request):
    """Get call statistics from Bitrix24 for the authenticated user."""
    try:
        user_id = request.user.id
        date_from = request.GET.get('date_from')
        date_to = request.GET.get('date_to')
        
        # Get local stats
        local_stats = get_local_call_stats(request.user, date_from, date_to)
        
        return Response({
            'local_stats': local_stats,
            'user_id': user_id
        })
        
    except Exception as e:
        logger.error(f"Error getting call stats: {str(e)}")
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

def get_local_call_stats(user, date_from=None, date_to=None):
    """Get local call statistics from Django database"""
    queryset = CallLog.objects.filter(user=user)
    
    if date_from:
        queryset = queryset.filter(timestamp__gte=date_from)
    if date_to:
        queryset = queryset.filter(timestamp__lte=date_to)
    
    total_calls = queryset.count()
    incoming_calls = queryset.filter(call_type='incoming').count()
    outgoing_calls = queryset.filter(call_type='outgoing').count()
    missed_calls = queryset.filter(call_type='missed').count()
    answered_calls = queryset.filter(is_answered=True).count()
    
    # Calculate total duration
    total_duration = sum([call.duration or 0 for call in queryset])
    
    # Get unique leads count
    unique_leads = queryset.exclude(bitrix_lead_id__isnull=True).values('bitrix_lead_id').distinct().count()
    
    # Get recordings count
    recordings_count = queryset.exclude(recording='').count()
    recordings_uploaded_to_bitrix = queryset.filter(recording_uploaded_to_bitrix=True).count()
    
    # 🆕 SYNC STATUS STATS
    registered_calls = queryset.filter(call_status='registered').count()
    completed_calls = queryset.filter(call_status='completed').count()
    recording_uploaded_calls = queryset.filter(call_status='recording_uploaded').count()
    failed_calls = queryset.filter(call_status='failed').count()
    
    return {
        'total_calls': total_calls,
        'incoming_calls': incoming_calls,
        'outgoing_calls': outgoing_calls,
        'missed_calls': missed_calls,
        'answered_calls': answered_calls,
        'total_duration_seconds': total_duration,
        'unique_leads': unique_leads,
        'recordings_count': recordings_count,
        'recordings_uploaded_to_bitrix': recordings_uploaded_to_bitrix,
        'sync_status': {
            'registered': registered_calls,
            'completed': completed_calls,
            'recording_uploaded': recording_uploaded_calls,
            'failed': failed_calls,
        }
    }

@api_view(['POST']) 
@permission_classes([IsAuthenticated])
def sync_call_to_bitrix(request, call_id):
    """Manually sync a specific call to Bitrix24."""
    try:
        call_log = CallLog.objects.get(id=call_id, user=request.user)
        
        bitrix_service = Bitrix24Service()
        
        call_data = {
            'phone_number': call_log.phone_number,
            'call_type': call_log.call_type,
            'start_time': call_log.timestamp.isoformat(),
            'staff_id': call_log.user.id,
            'caller_name': getattr(call_log, 'caller_name', ''),
            'duration': call_log.duration,
        }
        
        bitrix_result = bitrix_service.register_call(call_data, call_log)
        
        if bitrix_result and bitrix_result.get('success'):
            call_id = bitrix_result.get('call_id')
            lead_id = bitrix_result.get('lead_id')
            
            if call_id:
                call_log.bitrix_call_id = str(call_id)[:95]
                
            call_log.bitrix_lead_id = lead_id
            call_log.bitrix_synced = True
            call_log.bitrix_registered_at = timezone.now()
            call_log.call_status = 'registered'
            call_log.save()
            
            # 🆕 PROCESS CALL COMPLETION IF APPLICABLE
            if call_log.can_upload_to_bitrix:
                bitrix_service.process_call_completion(call_log)
            
            return Response({
                'success': True,
                'message': 'Call synced to Bitrix24',
                'bitrix_call_id': call_log.bitrix_call_id,
                'bitrix_lead_id': call_log.bitrix_lead_id,
                'recording_synced': call_log.recording_uploaded_to_bitrix,
                'call_status': call_log.call_status
            })
        else:
            return Response({
                'success': False,
                'message': 'Failed to sync call to Bitrix24'
            })
            
    except CallLog.DoesNotExist:
        return Response({'error': 'Call not found'}, status=status.HTTP_404_NOT_FOUND)
    except Exception as e:
        logger.error(f"Error syncing call: {str(e)}")
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_calls_by_lead(request, lead_id):
    """Get all calls associated with a specific Bitrix24 lead"""
    try:
        calls = CallLog.objects.filter(bitrix_lead_id=lead_id, user=request.user).order_by('-timestamp')
        serializer = CallLogSerializer(calls, many=True)
        
        # Count recordings
        recordings_count = calls.exclude(recording='').count()
        recordings_uploaded = calls.filter(recording_uploaded_to_bitrix=True).count()
        
        return Response({
            'success': True,
            'lead_id': lead_id,
            'total_calls': calls.count(),
            'recordings_count': recordings_count,
            'recordings_uploaded': recordings_uploaded,
            'calls': serializer.data
        })
        
    except Exception as e:
        logger.error(f"Error getting calls by lead: {str(e)}")
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_bitrix_users(request):
    """🆕 Get list of valid Bitrix24 users for mapping"""
    try:
        bitrix_service = Bitrix24Service()
        users = bitrix_service.get_bitrix_users()
        
        return Response({
            'success': True,
            'bitrix_users': users
        })
        
    except Exception as e:
        logger.error(f"Error getting Bitrix24 users: {str(e)}")
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def create_user_mapping(request):
    """🆕 Create user mapping between Django and Bitrix24"""
    try:
        django_user_id = request.data.get('django_user_id')
        bitrix_user_id = request.data.get('bitrix_user_id')
        bitrix_user_name = request.data.get('bitrix_user_name', '')
        
        if not django_user_id or not bitrix_user_id:
            return Response({'error': 'django_user_id and bitrix_user_id are required'}, status=status.HTTP_400_BAD_REQUEST)
        
        # Create or update mapping
        mapping, created = Bitrix24UserMapping.objects.update_or_create(
            django_user_id=django_user_id,
            defaults={
                'bitrix_user_id': bitrix_user_id,
                'bitrix_user_name': bitrix_user_name,
                'is_active': True
            }
        )
        
        return Response({
            'success': True,
            'created': created,
            'mapping': {
                'id': mapping.id,
                'django_user': mapping.django_user.username,
                'bitrix_user_id': mapping.bitrix_user_id,
                'bitrix_user_name': mapping.bitrix_user_name
            }
        })
        
    except Exception as e:
        logger.error(f"Error creating user mapping: {str(e)}")
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)




@api_view(['POST'])
@permission_classes([IsAuthenticated])
def register_and_finish_call(request):
    """Complete workflow: register call, then finish with recording"""
    try:
        # Extract data
        phone_number = request.data.get('phone_number')
        caller_name = request.data.get('caller_name', '')
        duration = int(request.data.get('duration', 0))
        recording_file = request.FILES.get('recording')
        
        if not phone_number:
            return Response({'error': 'phone_number is required'}, status=status.HTTP_400_BAD_REQUEST)
        
        print(f"🔄 Complete workflow for: {phone_number}")
        
        # Step 1: Create call log
        call_log = CallLog.objects.create(
            phone_number=phone_number,
            call_type='incoming',
            timestamp=timezone.now(),
            user=request.user,
            caller_name=caller_name,
            duration=duration,
            is_answered=True,
            start_time=timezone.now(),
            end_time=timezone.now()
        )
        
        print(f"💾 Created call log ID: {call_log.id}")
        
        # Step 2: Register with Bitrix24
        bitrix_service = Bitrix24Service()
        
        call_data = {
            'phone_number': phone_number,
            'call_type': 'incoming',
            'start_time': timezone.now().isoformat(),
            'staff_id': request.user.id,
            'caller_name': caller_name,
            'duration': duration,
        }
        
        bitrix_result = bitrix_service.register_call(call_data, call_log)
        
        if bitrix_result and bitrix_result.get('success'):
            # Update call log with Bitrix24 data
            call_id = bitrix_result.get('call_id')
            lead_id = bitrix_result.get('lead_id')
            
            if call_id:
                call_log.bitrix_call_id = str(call_id)[:95]
            if lead_id:
                call_log.bitrix_lead_id = int(lead_id)
            
            call_log.bitrix_synced = True
            call_log.bitrix_registered_at = timezone.now()
            call_log.call_status = 'registered'
            call_log.save()
        
        # Step 3: Handle recording
        recording_uploaded = False
        if recording_file:
            print(f"🎵 Processing recording file: {recording_file.name}")
            
            # Validate file
            if recording_file.size > 100 * 1024 * 1024:
                return Response({'error': 'Recording file too large (max 100MB)'}, status=status.HTTP_400_BAD_REQUEST)
            
            allowed_types = ['.mp3', '.wav', '.m4a']
            file_ext = os.path.splitext(recording_file.name)[1].lower()
            if file_ext not in allowed_types:
                return Response({'error': f'Invalid file type. Allowed: {allowed_types}'}, status=status.HTTP_400_BAD_REQUEST)
            
            try:
                unique_filename = f'recording_{call_log.id}_{int(timezone.now().timestamp())}{file_ext}'
                call_log.recording.save(unique_filename, recording_file)
                call_log.recording_duration = duration
                recording_uploaded = True
                print(f"✅ Recording saved for call {call_log.id}")
            except Exception as file_error:
                return Response({'error': f'Failed to save recording: {str(file_error)}'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        
        # Step 4: Process call completion with Bitrix24
        if call_log.bitrix_call_id and call_log.can_upload_to_bitrix:
            print(f"🔄 Processing call completion with Bitrix24...")
            success = bitrix_service.process_call_completion(call_log)
            
            if success:
                print(f"✅ Call completion processed successfully")
            else:
                print(f"❌ Failed to process call completion")
        
        return Response({
            'success': True,
            'call_id': call_log.id,
            'bitrix_call_id': call_log.bitrix_call_id,
            'bitrix_lead_id': call_log.bitrix_lead_id,
            'recording_uploaded': recording_uploaded,
            'recording_uploaded_to_bitrix': call_log.recording_uploaded_to_bitrix,
            'call_status': call_log.call_status,
            'message': 'Call processed successfully'
        })
        
    except Exception as e:
        print(f"💥 Error in register_and_finish_call: {str(e)}")
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)