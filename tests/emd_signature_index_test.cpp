#include "../cpp/emd_signature_index_fits.hpp"

#include <cassert>
#include <climits>

int main()
{
    assert(emd_signature_index_fits(1, INT_MAX, true));
    assert(emd_signature_index_fits(INT_MAX, 1, false));
    assert(emd_signature_index_fits(2, INT_MAX - 1, true));
    assert(!emd_signature_index_fits(2, INT_MAX, true));
    assert(emd_signature_index_fits(2, INT_MAX, false));
    assert(emd_signature_index_fits(INT_MAX / 2 + 1, 2, true));
    assert(!emd_signature_index_fits(INT_MAX / 2 + 2, 2, true));
    assert(emd_signature_index_fits(2, INT_MAX / 2, true));
    assert(!emd_signature_index_fits(3, INT_MAX / 2 + 1, true));
    assert(!emd_signature_index_fits(0, 2, true));
    assert(!emd_signature_index_fits(2, 0, false));
}
