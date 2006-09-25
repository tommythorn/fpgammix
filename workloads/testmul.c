int f(int a, int b)
{
        ((int *) 0x1000000000000)[11] = a;
        return a * b;
}

int main()
{
        return f(1729172917291729, 17291729172917291729);
}
