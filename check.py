import math

def check_sine_precision(filename="results.txt"):
    print(f"Проверка файла: {filename}")
    print("=" * 61)
    
    # Шапка таблицы
    print(f"{'Угол (рад)':>12} | {'Синус в файле':>14} | {'Точный синус':>13} | {'Погрешность':>12}")
    print("=" * 61)
    
    errors = []
    line_number = 0
    
    with open(filename, 'r') as file:
        for line in file:
            line_number += 1
            line = line.strip()
            
            if not line:
                continue
            
            parts = line.split(':')
            if len(parts) != 2:
                print(f"Строка {line_number}: Неверный формат (ожидается 'угол : значение')")
                continue
            
            try:
                angle_rad = float(parts[0].strip())
                given_sine = float(parts[1].strip())
            except ValueError:
                print(f"Строка {line_number}: Ошибка преобразования в число")
                continue
            
            true_sine = math.sin(angle_rad)
            difference = abs(true_sine - given_sine)
            
            # Выравнивание по фиксированной ширине
            print(f"{angle_rad:>12.6f} | {given_sine:>14.6f} | {true_sine:>13.6f} | {difference:>12.2e}")
            
            errors.append(difference)
    
    if errors:
        print("=" * 61)
        print(f"{'Максимальная погрешность:':<25} {max(errors):.2e}")
        print(f"{'Средняя погрешность:':<25} {sum(errors)/len(errors):.2e}")
        print(f"{'Количество проверенных значений:':<30} {len(errors)}")
        
        max_error_idx = errors.index(max(errors)) + 1
        print(f"{'Наибольшая погрешность в строке:':<30} {max_error_idx}")
    else:
        print("Не найдено корректных данных для проверки")

if __name__ == "__main__":
    check_sine_precision("results.txt")
