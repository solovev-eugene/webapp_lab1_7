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
