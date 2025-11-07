from django.urls import path
from calls.views import (
    save_call_log, 
    finish_call, 
    finish_call_with_recording,  # ADD THIS
    bitrix_call_stats, 
    CallLogListView, 
    sync_call_to_bitrix,
    register_incoming_call_immediately,
    get_calls_by_lead,
    register_and_finish_call
)

urlpatterns = [
    path('calls/', save_call_log, name='call-create'),
    path('calls/finish/', finish_call, name='call-finish'),
    path('calls/finish-with-recording/', finish_call_with_recording, name='finish-call-recording'),  # ADD THIS
    path('calls/stats/', bitrix_call_stats, name='bitrix-stats'),
    path('calls/list/', CallLogListView.as_view(), name='call-list'),
    path('calls/<int:call_id>/sync/', sync_call_to_bitrix, name='sync-call'),
    path('calls/register-immediate/', register_incoming_call_immediately, name='register-immediate'),
    path('calls/by-lead/<int:lead_id>/', get_calls_by_lead, name='calls-by-lead'),
    path('calls/register-and-finish/', register_and_finish_call, name='register-finish-call'),
]