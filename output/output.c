#include <stdio.h>
#include <stdlib.h>

int main() {
    int number1 = 10;
    int number2 = 5;
    int result = 0;
    printf("Starting calculation program\n");
    result = (number1 + number2);
    printf("%d\n", "'Addition result:'", result);
    result = (number1 - number2);
    printf("%d\n", "'Subtraction result:'", result);
    result = (number1 * number2);
    printf("%d\n", "'Multiplication result:'", result);
    if ((number1 > number2)) {
    printf("First number is larger\n");
    result = number1;
    } else {
    printf("Second number is larger or equal\n");
    result = number2;
    }
    printf("%d\n", "'Final result:'", result);
    int score = 85;
    if ((score > 90)) {
    printf("Grade: A\n");
    } else {
    printf("Grade: B or lower\n");
    }
    int calculation = ((20 + 15) - 5);
    printf("%d\n", "'Complex calculation:'", calculation);
    if ((calculation == 30)) {
    printf("Calculation is correct\n");
    } else {
    printf("Calculation needs review\n");
    }
    return 0;
}
