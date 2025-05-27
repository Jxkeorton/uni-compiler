#include <stdio.h>
#include <stdlib.h>

int main() {
    int number1 = 10;
    int number2 = 5;
    int result = 0;
    printf("Starting calculation program\n");
    result = (number1 + number2);
    printf("Addition result: %d\n", result);
    result = (number1 - number2);
    printf("Subtraction result: %d\n", result);
    result = (number1 * number2);
    printf("Multiplication result: %d\n", result);
    if ((number1 > number2)) {
    printf("First number is larger\n");
    result = number1;
    } else {
    printf("Second number is larger or equal\n");
    result = number2;
    }
    printf("Final result: %d\n", result);
    int score = 85;
    if ((score > 90)) {
    printf("Grade: A\n");
    } else {
    printf("Grade: B or lower\n");
    }
    int calculation = ((20 + 15) - 5);
    printf("Complex calculation: %d\n", calculation);
    if ((calculation == 30)) {
    printf("Calculation is correct\n");
    } else {
    printf("Calculation needs review\n");
    }
    return 0;
}
