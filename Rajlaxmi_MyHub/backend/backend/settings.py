from pathlib import Path
import os

# ===============================================================
# BASE DIR
# ===============================================================
BASE_DIR = Path(__file__).resolve().parent.parent

# ===============================================================
# SECURITY SETTINGS
# ===============================================================
SECRET_KEY = 'django-insecure-s&fzh4!h@a_oy+toc2w#)3$+6ywgjp$#l0%65-d82x1e(8za4)'
DEBUG = True

# ✅ Allow your local network and Flutter device
#ALLOWED_HOSTS = ['127.0.0.1', 'localhost', '192.168.1.17']



ALLOWED_HOSTS = ['*']  # For Development only 

# ===============================================================
# APPLICATIONS
# ===============================================================
INSTALLED_APPS = [
    # Default Django apps
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',

    # Third-party apps
    'rest_framework',
    'rest_framework.authtoken',  # ✅ Token authentication
    'corsheaders',

    # Your apps
    'accounts',  # For user auth
    'calls',     # For call data & recordings
]

# ===============================================================
# MIDDLEWARE
# ===============================================================
MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware',  # Must be first
    'django.middleware.common.CommonMiddleware',

    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

# ===============================================================
# URL CONFIG
# ===============================================================
ROOT_URLCONF = 'backend.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'backend.wsgi.application'

# ===============================================================
# DATABASE (PostgreSQL)
# ===============================================================
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'myhub_db',
        'USER': 'myhub_user',
        'PASSWORD': 'root123',
        'HOST': 'localhost',
        'PORT': '5432',
    }
}

# ===============================================================
# PASSWORD VALIDATORS
# ===============================================================
AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]

# ===============================================================
# INTERNATIONALIZATION
# ===============================================================
LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'Asia/Kolkata'
USE_I18N = True
USE_TZ = True

# ===============================================================
# STATIC FILES
# ===============================================================
STATIC_URL = 'static/'

# ===============================================================
# MEDIA FILES (call recordings, uploads)
# ===============================================================
MEDIA_URL = '/media/'
MEDIA_ROOT = os.path.join(BASE_DIR, 'media')

# ===============================================================
# DEFAULT PRIMARY KEY
# ===============================================================
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# ===============================================================
# CORS SETTINGS (allow Flutter mobile app)
# ===============================================================
CORS_ALLOW_ALL_ORIGINS = True
CORS_ALLOW_CREDENTIALS = True
CORS_ALLOW_HEADERS = [
    'content-type',
    'authorization',
    'accept',
    'origin',
    'user-agent',
    'x-csrftoken',
    'x-requested-with',
]


# Use your actual Bitrix24 webhook URL
BITRIX24_WEBHOOK_URL = 'https://world.bitrix24.com/rest/244/8w0b44xg96oamfqt/'
BITRIX24_DOMAIN = 'world.bitrix24.com'

# Optional: If you create separate webhooks for different functions
BITRIX24_WEBHOOKS = {
    
    'lead_creation': 'https://world.bitrix24.com/rest/244/8w0b44xg96oamfqt/',
    #'contact_search': 'https://world.bitrix24.com/rest/244/another-webhook-key/',
    #'telephony': 'https://world.bitrix24.com/rest/244/yet-another-webhook-key/',
}


# Configure logging
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'handlers': {
        'console': {
            'class': 'logging.StreamHandler',
        },
    },
    'root': {
        'handlers': ['console'],
        'level': 'INFO',
    }
}




# ===============================================================
# REST FRAMEWORK SETTINGS
# ===============================================================
REST_FRAMEWORK = {
    # ✅ By default, require authentication for all views
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.IsAuthenticated',
    ],
    'DEFAULT_AUTHENTICATION_CLASSES': [
        'rest_framework.authentication.TokenAuthentication',
        'rest_framework.authentication.SessionAuthentication',
    ],
}

# ===============================================================
# CSRF EXEMPT URLS (for Flutter APIs)
# ===============================================================
CSRF_TRUSTED_ORIGINS = [
    'http://192.168.1.17:8000',
    'http://localhost:8000',
]

# ✅ Important: Override authentication for public endpoints
# Add this in your accounts/views.py for register/login:
# @permission_classes([AllowAny])
