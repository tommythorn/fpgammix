main()
{
        *(int*) 0x1000000000000ULL = 'T';
        *(int*) 0x123456789ABC0ULL = 'S';
        *(int*) 0x123456879ABC0ULL = 'S';
        *(int*) 0x123546789ABC0ULL = 'S';
        *(int*) 0x12345679A8BC0ULL = 'S';
        *(int*) 0x123564789ABC0ULL = 'S';
        *(int*) 0x213456789ABC0ULL = 'S';
        *(int*) 0x213456879ABC0ULL = 'S';
        *(int*) 0x213546789ABC0ULL = 'S';
        *(int*) 0x21345679A8BC0ULL = 'S';
        *(int*) 0x213564789ABC0ULL = 'S';
        *(int*) 0x231456789ABC0ULL = 'S';
        *(int*) 0x231456879ABC0ULL = 'S';
        *(int*) 0x231546789ABC0ULL = 'S';
        *(int*) 0x23145679A8BC0ULL = 'S';
        *(int*) 0x231564789ABC0ULL = 'S';
        *(int*) 0x923456789ABC0ULL = 'S';
        *(int*) 0x923456879ABC0ULL = 'S';
        *(int*) 0x923546789ABC0ULL = 'S';
        *(int*) 0x92345679A8BC0ULL = 'S';
        *(int*) 0x923564789ABC0ULL = 'S';
}
