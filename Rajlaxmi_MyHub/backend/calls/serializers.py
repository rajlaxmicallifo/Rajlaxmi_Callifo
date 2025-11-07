from rest_framework import serializers
from .models import CallLog


class CallLogSerializer(serializers.ModelSerializer):
    # Custom read-only fields
    user_email = serializers.SerializerMethodField(read_only=True)
    formatted_duration = serializers.SerializerMethodField(read_only=True)
    has_recording = serializers.SerializerMethodField(read_only=True)

    class Meta:
        model = CallLog
        # Exclude the user because we’ll set it automatically in the view
        exclude = ['user']

    # Get the user's email linked to this call log
    def get_user_email(self, obj):
        return obj.user.email if obj.user else None

    # Return formatted call duration (e.g., 2m 15s)
    def get_formatted_duration(self, obj):
        return obj.formatted_duration()

    # Check if the call has a recording file
    def get_has_recording(self, obj):
        return obj.has_recording
