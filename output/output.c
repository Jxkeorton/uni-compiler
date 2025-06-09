#include <stdio.h>

int main() {
    int number1 = 10;
    int number2 = 5;
    int result = 0;
    printf("Starting calculation program\n");
    result = (number1 + number2);
    printf("%d\n", result);
    int calculation = ((20 + 10) - 5);
    printf("%d\n", calculation);
    if ((calculation == 25)) {
    printf("Calculation is correct\n");
    } else {
    printf("Calculation needs review\n");
    }
    return 0;
}
