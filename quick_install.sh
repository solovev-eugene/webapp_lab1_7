echo "Создание структуры..."

mkdir webapp_lab1_7
cd webapp_lab1_7
mkdir static templates
touch app.py utils.py config.py forms.py requirements.txt .env.example .gitignore static/style.css templates/index.html

echo "Заполнение файлов..."
echo "-- Конфигурационные файлы..."
echo ""
echo ""
echo ""
echo "=========================================="
echo "Настройка Google reCAPTCHA"
echo "=========================================="
echo ""
echo "Получить ключи можно по адресу:"
echo "https://www.google.com/recaptcha/admin"
echo ""
echo "Оставьте поля пустыми, если не хотите использовать reCAPTCHA"
echo ""

# Запрос SITE KEY
read -p "Введите SITE_KEY (для клиентской части): " GOOGLE_RECAPTCHA_SITE_KEY
if [ -z "$GOOGLE_RECAPTCHA_SITE_KEY" ]; then
    GOOGLE_RECAPTCHA_SITE_KEY="google_recaptcha_site_key"
    echo "Будет использован ключ-заглушка"
fi

echo ""

# Запрос SECRET KEY
read -s -p "Введите SECRET_KEY (для серверной части): " GOOGLE_RECAPTCHA_SECRET_KEY
if [ -z "$GOOGLE_RECAPTCHA_SECRET_KEY" ]; then
    GOOGLE_RECAPTCHA_SECRET_KEY="google_recaptcha_secret_key"
    echo "Будет использован ключ-заглушка"
fi


cat > .env.example << EOF
# Сервер
PORT=5000
HOST=localhost
DEBUG=True

# Настройки
MAX_CONTENT_LENGTH=16777216
ALLOWED_EXTENSIONS=png,jpg,jpeg,gif,webp,bmp
OUTPUT_FORMAT=png

# Секретный ключ
SECRET_KEY=$(openssl rand -hex 32)

# API ключи
GOOGLE_RECAPTCHA_SITE_KEY=$(GOOGLE_RECAPTCHA_SITE_KEY)
GOOGLE_RECAPTCHA_SECRET_KEY=$(GOOGLE_REGOOGLE_RECAPTCHA_SECRET_KEYCAPTCHA_SECRET_KEY)
EOF

cat > .gitignore << EOF
# Виртуальное окружение
venv/
env/
.venv/

# Статические файлы
static/*
flask_session/
!static/style.css

# Кэш Python
__pycache__/
*.pyc
*.pyo

# Файлы IDE
.vscode/
.idea/
tempCodeRunnerFile*

# Системные файлы
.DS_Store
Thumbs.db

# Файлы с секретами
.env
*.log

# Базы данных
*.db
*.sqlite3
EOF

cat > requirements.txt << EOF
blinker==1.9.0
cachelib==0.14.0
certifi==2026.7.22
charset-normalizer==3.4.9
click==8.4.2
contourpy==1.3.2
cycler==0.12.1
Flask==3.1.3
Flask-Session==0.8.0
Flask-WTF==1.3.0
fonttools==4.63.0
idna==3.18
itsdangerous==2.2.0
Jinja2==3.1.6
kiwisolver==1.5.0
MarkupSafe==3.0.3
matplotlib==3.10.9
msgspec==0.21.1
numpy==2.2.6
packaging==26.2
pillow==12.3.0
pyparsing==3.3.2
python-dateutil==2.9.0.post0
requests==2.34.2
six==1.17.0
urllib3==2.7.0
Werkzeug==3.1.8
WTForms==3.2.2
EOF

echo "-- Код приложения..."

cat > app.py << EOF
'''
Модуль app.py - основное приложение Flask.

Этот модуль содержит:
- Базовую конфигурацию
- Определение маршрутов приложения
'''

from flask import (
    Flask, flash, redirect,
    render_template, session, url_for
)
from flask_session import Session

from config import *
from utils import *
from forms import ImageForm

# Инициализация приложения
app = Flask(
    __name__,
    template_folder=TEMPLATES_DIR,
    static_folder=STATIC_DIR,
)

# ----------------------- КОНФИГУРАЦИЯ -----------------------

# CSRF
app.config['SECRET_KEY'] = SECRET_KEY

# Параметры reCAPTCHA
app.config['RECAPTCHA_PUBLIC_KEY'] = os.environ.get(
    'GOOGLE_RECAPTCHA_SITE_KEY')
app.config['RECAPTCHA_PRIVATE_KEY'] = os.environ.get(
    'GOOGLE_RECAPTCHA_SECRET_KEY')
app.config['RECAPTCHA_PARAMETERS'] = {'hl': 'ru'}  # Русский язык

# Максимальный размер загружаемого файла
app.config['MAX_CONTENT_LENGTH'] = MAX_CONTENT_LENGTH

# Сессионные настройки и запуск сессии
app.config['SESSION_TYPE'] = 'filesystem'  # Хранить на диске
app.config['SESSION_PERMANENT'] = False
app.config['SESSION_USE_SIGNER'] = True
Session(app)


# ------------------------- МАРШРУТЫ -------------------------

@app.route('/', methods=['GET', 'POST'])
def index():
    ''' Главная страница '''
    # Формы для загрузки изображения
    form = ImageForm()

    # Загрузка нового изображения
    if form.validate_on_submit():
        session['original_image'] = file_to_base64(form.image.data)
        flash('Изображение загружено!', 'success')

    if session.get('original_image'):
        image = base64_to_image(session['original_image'])
        mode = form.mode.data  # Выбранный порядок каналов RGB

        # Обработка изображения и создание графиков
        histogram = generate_histogram(image)  # График распределения
        image = process_image(image, mode)  # Смена цифровой карты
        diagram = generate_diagram(image)  # График средних значений

        # Сохранение изображений в сессии
        session['image'] = image_to_base64(image)
        session['histogram'] = histogram
        session['diagram'] = diagram

    # Шаблон передаваемых данных
    context = {
        'title': 'RGB-редактор',  # Заголовок страницы
        'form': form,
        'image': {
            'src': session.get('image'),
            'title': 'Изображение',
            'description': 'Обработанное изображение'
        },
        'histogram': {
            'src': session.get('histogram'),
            'title': 'Гистограмма',
            'description': 'Графики распределения цветов исходной картинки'
        },
        'diagram': {
            'src': session.get('diagram'),
            'title': 'Диаграмма',
            'description': 'Графики среднего значения цвета по вертикали и горизонтали'
        }
    }
    return render_template('index.html', **context)


@app.route('/clear', methods=['POST'])
def clear_session():
    '''Очистка сессии'''
    session.clear()
    flash('Сессия очищена', 'info')
    return redirect(url_for('index'))


@app.errorhandler(413)
def too_large(e):
    '''Обработка слишком больших файлов.'''
    flash(f'Файл слишком большой. \
        Максимальный размер: {MAX_CONTENT_LENGTH / 1024 / 1024} МБ', 'danger')
    return redirect(url_for('index'))


@app.errorhandler(500)
def internal_error(e):
    '''Обработка внутренних ошибок.'''
    app.logger.error(f'Internal error: {e}')
    flash('Внутренняя ошибка сервера', 'danger')
    return redirect(url_for('index'))


if __name__ == '__main__':
    app.run(
        host=HOST,
        port=PORT,
        debug=DEBUG
    )
EOF

cat > utils.py << EOF
'''
Модуль utils.py - функционал приложения Flask.

Этот модуль содержит функции обработки изображений
'''

from flask_wtf.file import FileStorage
from matplotlib.figure import Figure

from io import BytesIO
import numpy as np
import matplotlib.pyplot as plt
from base64 import b64decode, b64encode
from PIL import Image

from config import OUTPUT_FORMAT

PREFIX = f'data:image/{OUTPUT_FORMAT};base64,'


def file_to_base64(file: FileStorage, prefix=PREFIX) -> str:
    '''Сохраняет объект Flask.FileStorage в Base64'''
    file_data = file.read()
    img_base64 = b64encode(file_data).decode()
    return prefix + img_base64


def image_to_base64(img: Image.Image, prefix: str = PREFIX, output_format: str = OUTPUT_FORMAT) -> str:
    '''Сохраняет объект PIL.Image в Base64'''
    buffered = BytesIO()
    img.save(buffered, format=f'{output_format}')
    img_base64 = b64encode(buffered.getvalue()).decode()
    return prefix + img_base64


def figure_to_base64(fig: Figure, prefix: str = PREFIX) -> str:
    '''Сохраняет фигуру Matplotlib в Base64'''
    buffered = BytesIO()
    fig.savefig(buffered, format='png', dpi=100, bbox_inches='tight')
    plt.close(fig)
    img_base64 = b64encode(buffered.getvalue()).decode()
    return prefix + img_base64


def base64_to_image(str_base64: str) -> Image.Image:
    '''Конвертирует Base64 в PIL.Image с цветовой моделью RGB'''
    if ',' in str_base64:
        str_base64 = str_base64.split(',')[1]
    img_data = b64decode(str_base64)
    img = Image.open(BytesIO(img_data))
    if img.mode != 'RGB':
        img = img.convert('RGB')
    return img


def process_image(img: Image.Image, mode: str) -> Image.Image:
    '''Меняет цветовую карту изображения'''
    if mode == 'NEGATIVE':
        return Image.eval(img, lambda x: 255 - x)
    elif mode == 'GRAYSCALE':
        return img.convert('L').convert('RGB')
    else:
        r, g, b = img.split()
        blank = Image.new('L', img.size, 0)

        channel_handlers = {
            'R': lambda: Image.merge('RGB', (r, r, r)),
            'G': lambda: Image.merge('RGB', (g, g, g)),
            'B': lambda: Image.merge('RGB', (b, b, b)),
            'RG': lambda: Image.merge('RGB', (r, g, blank)),
            'RB': lambda: Image.merge('RGB', (r, blank, b)),
            'GB': lambda: Image.merge('RGB', (blank, g, b)),
            'BGR': lambda: Image.merge('RGB', (b, g, r)),
            'GBR': lambda: Image.merge('RGB', (g, b, r)),
            'RBG': lambda: Image.merge('RGB', (r, b, g)),
            'SWAP_RB': lambda: Image.merge('RGB', (b, g, r)),
            'SWAP_RG': lambda: Image.merge('RGB', (g, r, b)),
            'SWAP_GB': lambda: Image.merge('RGB', (r, b, g)),
        }
        return channel_handlers.get(mode, lambda: img)()


def generate_histogram(img: Image.Image) -> str:
    '''Генерирует гистограмму распределения цветов'''
    img_array = np.array(img)
    r = img_array[:, :, 0].flatten()
    g = img_array[:, :, 1].flatten()
    b = img_array[:, :, 2].flatten()

    fig, ax = plt.subplots(figsize=(10, 6))
    ax.hist(r, bins=256, color='red', alpha=0.6, label='Red', range=(0, 255))
    ax.hist(g, bins=256, color='green', alpha=0.6,
            label='Green', range=(0, 255))
    ax.hist(b, bins=256, color='blue', alpha=0.6, label='Blue', range=(0, 255))
    ax.set_xlabel('Яркость')
    ax.set_ylabel('Количество пикселей')
    ax.set_title('Распределение цветов в исходном изображении')
    ax.legend()
    ax.grid(True, alpha=0.3)

    return figure_to_base64(fig)


def generate_diagram(img: Image.Image) -> str:
    '''
    Генерирует графики средних значений по вертикали и горизонтали
    '''
    img_array = np.array(img)
    height, width, _ = img_array.shape

    # Средние значения по вертикали (для каждого столбца)
    vertical_means = {
        'R': np.mean(img_array[:, :, 0], axis=0),
        'G': np.mean(img_array[:, :, 1], axis=0),
        'B': np.mean(img_array[:, :, 2], axis=0)
    }

    # Средние значения по горизонтали (для каждой строки)
    horizontal_means = {
        'R': np.mean(img_array[:, :, 0], axis=1),
        'G': np.mean(img_array[:, :, 1], axis=1),
        'B': np.mean(img_array[:, :, 2], axis=1)
    }

    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 5))

    # График 1: Среднее по вертикали
    x = np.arange(width)
    ax1.plot(x, vertical_means['R'], color='red',
             alpha=0.8, label='Red', linewidth=1.5)
    ax1.plot(x, vertical_means['G'], color='green',
             alpha=0.8, label='Green', linewidth=1.5)
    ax1.plot(x, vertical_means['B'], color='blue',
             alpha=0.8, label='Blue', linewidth=1.5)
    ax1.set_xlabel('Столбец (x)')
    ax1.set_ylabel('Средняя яркость')
    ax1.set_title('Среднее значение цвета по вертикали')
    ax1.legend()
    ax1.grid(True, alpha=0.3)
    ax1.set_ylim(0, 255)

    # График 2: Среднее по горизонтали
    y = np.arange(height)
    ax2.plot(y, horizontal_means['R'], color='red',
             alpha=0.8, label='Red', linewidth=1.5)
    ax2.plot(y, horizontal_means['G'], color='green',
             alpha=0.8, label='Green', linewidth=1.5)
    ax2.plot(y, horizontal_means['B'], color='blue',
             alpha=0.8, label='Blue', linewidth=1.5)
    ax2.set_xlabel('Строка (y)')
    ax2.set_ylabel('Средняя яркость')
    ax2.set_title('Среднее значение цвета по горизонтали')
    ax2.legend()
    ax2.grid(True, alpha=0.3)
    ax2.set_ylim(0, 255)

    plt.tight_layout()

    return figure_to_base64(fig)
EOF

cat > config.py << EOF
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
EOF

cat > forms.py << EOF
'''
Модуль forms.py - формы приложения Flask.

Этот модуль содержит форму для загрузки данных и обработки капчи.
'''

from flask_wtf import FlaskForm, RecaptchaField
from flask_wtf.file import DataRequired, FileField, FileRequired, FileAllowed
from wtforms import HiddenField, SelectField, SubmitField

from config import ALLOWED_EXTENSIONS


class ImageForm(FlaskForm):
    '''Форма для загрузки изображения'''
    image = FileField(
        label='Выберите изображение',
        validators=[
            FileRequired('Пожалуйста, выберите файл'),
            FileAllowed(
                ALLOWED_EXTENSIONS,
                f'Разрешенные форматы: {ALLOWED_EXTENSIONS}')
        ]
    )
    mode = SelectField('Режим каналов', choices=[
        ('RGB', 'Оригинал (RGB)'),
        ('R', 'Только красный'),
        ('G', 'Только зелёный'),
        ('B', 'Только синий'),
        ('RG', 'Красный + зелёный'),
        ('RB', 'Красный + синий'),
        ('GB', 'Зелёный + синий'),
        ('BGR', 'BGR (синий-зелёный-красный)'),
        ('GBR', 'GBR (зелёный-синий-красный)'),
        ('RBG', 'RBG (красный-синий-зелёный)'),
        ('SWAP_RB', 'Поменять R и B местами'),
        ('SWAP_RG', 'Поменять R и G местами'),
        ('SWAP_GB', 'Поменять G и B местами'),
        ('NEGATIVE', 'Негатив'),
        ('GRAYSCALE', 'Черно-белый')
    ], default='RGB')

    submit = SubmitField('Загрузить изображение')
    submit_mode = SubmitField('Поменять цветовую карту')
    recaptcha = RecaptchaField()
EOF

echo "-- Файлы фронтенды..."

cat > templates/index.html << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{{ title }}</title>
    <link rel="stylesheet" href="{{ url_for('static', filename='style.css') }}">
</head>
<body>
    <h1>RGB-редактор изображения</h1>
    {% if not image.src %}
        <form method="post" enctype="multipart/form-data">
            {{ form.recaptcha }}
            {{ form.hidden_tag() }}
            {{ form.image }}
            {{ form.submit }}
        </form>
    {% else %}
        <form method="post">
            {{ form.hidden_tag() }}
            {{ form.mode }}
            {{ form.submit_mode }}
        </form>
        <img src="{{ image.src }}" title='{{ image.title }}' alt="{{ image.description }}">
        <img src="{{ histogram.src }}" title='{{ histogram.title }}' alt="{{ histogram.description }}">
        <img src="{{ diagram.src }}" title='{{ diagram.title }}' alt="{{ diagram.description }}">
        <form action="{{ url_for('clear_session') }}" method="post">
            <input type="hidden" name="csrfmiddlewaretoken" value="{{ csrf_token }}">
            <button type="submit">Очистить сессию</button>
        </form>
    {% endif %}
    <!-- Flash сообщения -->
    {% with messages = get_flashed_messages(with_categories=true) %}
        {% if messages %}
            {% for category, message in messages %}
                <div class="flash-messages flash-{{ category }}">
                    {{ message }}
                </div>
            {% endfor %}
        {% endif %}
    {% endwith %}
</body>
</html>
EOF

cat > static/style.css << EOF
* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

body {
    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
    max-width: 1200px;
    margin: 0 auto;
    padding: 30px 20px;
    background: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%);
    min-height: 100vh;
    color: #2c3e50;
}

h1 {
    text-align: center;
    font-size: 2.5rem;
    font-weight: 700;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
    margin-bottom: 30px;
    letter-spacing: -0.5px;
}

form {
    background: rgba(255, 255, 255, 0.9);
    backdrop-filter: blur(10px);
    padding: 30px;
    border-radius: 20px;
    box-shadow: 0 20px 60px rgba(0, 0, 0, 0.1);
    max-width: 500px;
    margin: 0 auto 30px;
    transition: transform 0.3s ease, box-shadow 0.3s ease;
    display: flex;
    flex-direction: column;
    align-items: center;
}

form:hover {
    transform: translateY(-2px);
    box-shadow: 0 25px 70px rgba(0, 0, 0, 0.15);
}

form input[type="file"] {
    display: block;
    width: auto;
    padding: 15px;
    border: 2px dashed #667eea;
    border-radius: 12px;
    background: #f8f9ff;
    cursor: pointer;
    transition: all 0.3s ease;
    font-size: 1rem;
    margin-bottom: 15px;
}

form input[type="file"]:hover {
    border-color: #764ba2;
    background: #f0f2ff;
}

form input[type="submit"],
form button[type="submit"] {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: white;
    border: none;
    padding: 14px 30px;
    border-radius: 12px;
    font-size: 1rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.3s ease;
    width: auto;
    margin-top: 15px;
    letter-spacing: 0.5px;
    text-transform: uppercase;
}

form input[type="submit"]:hover,
form button[type="submit"]:hover {
    transform: scale(1.02);
    box-shadow: 0 10px 25px rgba(102, 126, 234, 0.4);
}

form select {
    width: 100%;
    padding: 12px 15px;
    border: 2px solid #e0e5ec;
    border-radius: 12px;
    font-size: 1rem;
    background: white;
    transition: all 0.3s ease;
    margin-bottom: 15px;
}

form select:focus {
    outline: none;
    border-color: #667eea;
    box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
}

.g-recaptcha {
    margin: 10px 15px;
    display: flex;
    justify-content: center;
}

.g-recaptcha>div {
    margin: 0 auto;
}

img {
    max-width: 100%;
    height: auto;
    border-radius: 16px;
    box-shadow: 0 10px 40px rgba(0, 0, 0, 0.1);
    display: block;
    margin: 20px auto;
    transition: all 0.4s ease;
}

img:hover {
    transform: scale(1.02);
    box-shadow: 0 15px 50px rgba(0, 0, 0, 0.15);
}

img[src*="histogram"],
img[src*="diagram"] {
    display: inline-block;
    width: 45%;
    margin: 10px 2%;
}

@media (max-width: 768px) {

    img[src*="histogram"],
    img[src*="diagram"] {
        width: 100%;
        margin: 10px 0;
    }
}

form:last-of-type {
    background: transparent;
    backdrop-filter: none;
    box-shadow: none;
    padding: 0;
    max-width: 200px;
}

form:last-of-type button {
    background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
    font-size: 0.9rem;
    padding: 12px 25px;
    text-transform: none;
}

form:last-of-type button:hover {
    box-shadow: 0 10px 25px rgba(245, 87, 108, 0.4);
}

.flash-messages {
    max-width: 500px;
    margin: 20px auto;
    padding: 15px 25px;
    border-radius: 12px;
    font-weight: 500;
    animation: slideIn 0.5s ease;
    box-shadow: 0 10px 30px rgba(0, 0, 0, 0.05);
    text-align: center;
}

.flash-success {
    background: linear-gradient(135deg, #a8edea 0%, #fed6e3 100%);
    color: #1a4a47;
    border-left: 4px solid #2ecc71;
}

.flash-error {
    background: linear-gradient(135deg, #fbc2eb 0%, #a18cd1 100%);
    color: #6c3483;
    border-left: 4px solid #e74c3c;
}

.flash-warning {
    background: linear-gradient(135deg, #fdcbf1 0%, #e6dee9 100%);
    color: #7d6608;
    border-left: 4px solid #f39c12;
}

.flash-info {
    background: linear-gradient(135deg, #a1c4fd 0%, #c2e9fb 100%);
    color: #1a3a5c;
    border-left: 4px solid #3498db;
}

@keyframes slideIn {
    from {
        opacity: 0;
        transform: translateY(-20px);
    }

    to {
        opacity: 1;
        transform: translateY(0);
    }
}

@media (max-width: 480px) {
    body {
        padding: 15px 10px;
    }

    h1 {
        font-size: 1.8rem;
    }

    form {
        padding: 20px;
        margin: 0 0 20px;
    }

    img {
        margin: 10px 0;
    }

    .g-recaptcha {
        transform: scale(0.85);
        transform-origin: center center;
    }
}

input[type="hidden"] {
    display: none;
}
EOF

echo "Все файлы успешно установлены!"

echo "Установка и активация виртуального окружения..."

python3.10 -m venv .venv
source .venv/bin/activate

echo "Установка пакетов..."

pip install --upgrade pip
pip install -r requirements.txt

echo "Поздравляю! Приложение установлено на ваш компьютер!"
echo "Чтобы им воспользоваться - запустите app,py."

