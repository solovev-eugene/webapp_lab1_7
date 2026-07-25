'''
Модуль config.py - настройки приложения Flask.

Этот модуль содержит:
- Расширенную и масштабируемую конфигурацию
- Извлечение переменных из файла .env
'''

import os
from pathlib import Path

# Корень проекта
BASE_DIR: Path = Path(__file__).parent

# Папки проекта
STATIC_DIR: Path = BASE_DIR / 'static'
TEMPLATES_DIR: Path = BASE_DIR / 'templates'

# Файл конфигурации
ENV_PATH: Path = BASE_DIR / '.env'

# Проверка наличия файла переменных окружения
if ENV_PATH.exists():
    # Счетчик загруженных переменных
    loaded_counter = 0

    # Чтение файла
    with open(ENV_PATH, 'r', encoding='utf-8') as file:
        for line in file:
            line = line.strip()

            # Пропуск пустых строк и строк-комментариев
            if not line or line.startswith('#'):
                continue

            # Запись переменных в словарь
            if '=' in line:
                key, value = line.split('=', 1)
                os.environ[key] = value
                loaded_counter += 1

#     print(f"Загружено переменных: {loaded_counter}")
# else:
#     print(
#         f' Файл конфигураций не найден, буду использованы настройки по умолчанию.')


# Секреты
SECRET_KEY: str = os.environ.get('SECRET_KEY', 'dev_key_12345')
GOOGLE_RECAPTCHA_SITE_KEY: str = os.environ.get(
    'GOOGLE_RECAPTCHA_SITE_KEY', 'google_recaptcha_site_key')
GOOGLE_RECAPTCHA_SECRET_KEY: str = os.environ.get(
    'GOOGLE_RECAPTCHA_SECRET_KEY', 'google_recaptcha_secret_key')

# Сервер
HOST: str = os.environ.get('HOST', '127.0.0.1')
PORT: int = int(os.environ.get('PORT', 5000))
DEBUG: bool = os.environ.get('DEBUG', 'False').lower() == 'true'

# Загрузка файлов (значение в байтах)
MAX_CONTENT_LENGTH: int = int(
    os.environ.get('MAX_CONTENT_LENGTH', 16777216))

# Допустимые расширения файлов
ALLOWED_EXTENSIONS: set[str] = set(
    os.environ.get(
        'ALLOWED_EXTENSIONS',
        'png,jpg,jpeg,gif,webp,bmp'
    ).split(',')
)
OUTPUT_FORMAT: str = os.environ.get('OUTPUT_FORMAT', 'png')
