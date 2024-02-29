# To run these tests, simply execute `nimble test` from within
# the root of the project directory (where the .nimble file is)

import unittest
import lpg

test "can add":
    check 5 + 5 == 10
    check "this" == "this"
