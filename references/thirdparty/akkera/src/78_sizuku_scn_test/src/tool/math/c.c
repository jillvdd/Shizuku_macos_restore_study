#include <stdio.h>
#include <math.h>


int multiply(int x, int y)
{
    return ( ( long )x * ( long )y ) / 16;
}


int main(int argc, char* argv[])
{
	int i = 30 * 16;
	int j = 0.75 * 16;
	int k = multiply(i, j);

	int z = k / 16;
	printf("%d\n", z);

    return 0;
}

