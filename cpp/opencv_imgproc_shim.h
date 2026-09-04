#ifndef OPENCV_IMGPROC_SHIM_H
#define OPENCV_IMGPROC_SHIM_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct opencv_core_mat_handle opencv_core_mat_handle;

typedef int32_t opencv_imgproc_status;

#define OPENCV_IMGPROC_OK                     ((opencv_imgproc_status)0)
#define OPENCV_IMGPROC_ERROR_OPENCV           ((opencv_imgproc_status)1)
#define OPENCV_IMGPROC_ERROR_STD              ((opencv_imgproc_status)2)
#define OPENCV_IMGPROC_ERROR_UNKNOWN          ((opencv_imgproc_status)3)
#define OPENCV_IMGPROC_ERROR_INVALID_ARGUMENT ((opencv_imgproc_status)4)

#define OPENCV_IMGPROC_COLOR_BGR_TO_GRAY ((int32_t)0)

#define OPENCV_IMGPROC_INTER_NEAREST  ((int32_t)0)
#define OPENCV_IMGPROC_INTER_LINEAR   ((int32_t)1)
#define OPENCV_IMGPROC_INTER_CUBIC    ((int32_t)2)
#define OPENCV_IMGPROC_INTER_AREA     ((int32_t)3)
#define OPENCV_IMGPROC_INTER_LANCZOS4 ((int32_t)4)

const char *opencv_imgproc_last_error_message(void);

opencv_imgproc_status
opencv_imgproc_cvt_color(
    const opencv_core_mat_handle *source,
    opencv_core_mat_handle *destination,
    int32_t conversion);

opencv_imgproc_status
opencv_imgproc_resize(
    const opencv_core_mat_handle *source,
    opencv_core_mat_handle *destination,
    int32_t width,
    int32_t height,
    int32_t interpolation);

#ifdef __cplusplus
}
#endif

#endif
