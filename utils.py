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
