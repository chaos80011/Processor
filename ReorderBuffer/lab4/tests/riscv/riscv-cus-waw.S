#include "riscv-macros.h"

        TEST_RISCV_BEGIN

        li    x2, 2
        mul   x3, x2, x2
        li    x3, 2
        add   x4, x2, x3
        TEST_CHECK_EQ( x4, 4 )

        TEST_RISCV_END