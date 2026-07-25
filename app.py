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
