/**
 * Утилита для валидации и обработки массивов строк
 */

/**
 * Фильтрует и валидирует массив email-адресов
 * @param emails - массив строк для валидации
 * @param allowEmpty - разрешить пустой массив
 * @returns отфильтрованный массив валидных email-адресов
 * @throws Error если массив пуст и allowEmpty = false
 */
export const validateEmailArray = (emails: string[], allowEmpty: boolean = true): string[] => {
  if (!Array.isArray(emails)) {
    throw new Error('Входные данные должны быть массивом');
  }

  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  const validEmails = emails.filter(email => {
    if (typeof email !== 'string') return false;
    return emailRegex.test(email.trim());
  });

  if (!allowEmpty && validEmails.length === 0) {
    throw new Error('Массив должен содержать хотя бы один валидный email');
  }

  return validEmails;
};

/**
 * Вычисляет среднее значение из массива чисел
 * @param numbers - массив чисел
 * @returns среднее значение (вещественное число)
 * @throws Error если массив пуст или содержит нечисловые значения
 */
export const calculateAverage = (numbers: number[]): number => {
  if (!Array.isArray(numbers)) {
    throw new Error('Входные данные должны быть массивом');
  }

  if (numbers.length === 0) {
    throw new Error('Массив не может быть пустым');
  }

  const sum = numbers.reduce((acc, num) => {
    if (typeof num !== 'number' || isNaN(num)) {
      throw new Error('Массив должен содержать только числа');
    }
    return acc + num;
  }, 0);

  return sum / numbers.length;
};

