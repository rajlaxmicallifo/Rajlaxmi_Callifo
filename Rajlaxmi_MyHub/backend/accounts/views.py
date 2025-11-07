from django.contrib.auth.models import User
from django.contrib.auth import authenticate
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny  # ✅ Import this
from rest_framework.response import Response
from rest_framework import status
from rest_framework.authtoken.models import Token

# ===============================
# Register API
# ===============================
@api_view(['POST'])
@permission_classes([AllowAny])  # ✅ Make public
def register(request):
    name = request.data.get('name')
    email = request.data.get('email')
    password = request.data.get('password')

    if not name or not email or not password:
        return Response({'error': 'All fields are required.'}, status=status.HTTP_400_BAD_REQUEST)

    if User.objects.filter(username=email).exists():
        return Response({'error': 'Email already exists'}, status=status.HTTP_400_BAD_REQUEST)

    user = User.objects.create_user(username=email, email=email, password=password, first_name=name)
    user.save()

    token, created = Token.objects.get_or_create(user=user)

    return Response({
        'message': 'User registered successfully',
        'token': token.key,
        'name': user.first_name,
        'email': user.email
    }, status=status.HTTP_201_CREATED)


# ===============================
# Login API
# ===============================
@api_view(['POST'])
@permission_classes([AllowAny])  # ✅ Make public
def login(request):
    email = request.data.get('email')
    password = request.data.get('password')

    if not email or not password:
        return Response({'error': 'Email and password are required'}, status=status.HTTP_400_BAD_REQUEST)

    user = authenticate(username=email, password=password)

    if user:
        token, created = Token.objects.get_or_create(user=user)
        return Response({
            'message': 'Login successful',
            'token': token.key,
            'name': user.first_name,
            'email': user.email
        }, status=status.HTTP_200_OK)
    else:
        return Response({'error': 'Invalid email or password'}, status=status.HTTP_401_UNAUTHORIZED)
