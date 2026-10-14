#include <cstdint>
static_assert(sizeof(void *) == 8, "target pointer size");
extern "C" std::int32_t opencv_imgproc_cross_probe() { return 0; }