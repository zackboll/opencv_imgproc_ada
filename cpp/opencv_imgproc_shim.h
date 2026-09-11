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

#define OPENCV_IMGPROC_BORDER_CONSTANT     ((int32_t)0)
#define OPENCV_IMGPROC_BORDER_REPLICATE    ((int32_t)1)
#define OPENCV_IMGPROC_BORDER_REFLECT      ((int32_t)2)
#define OPENCV_IMGPROC_BORDER_REFLECT_101  ((int32_t)3)

#define OPENCV_IMGPROC_MORPH_RECTANGLE ((int32_t)0)
#define OPENCV_IMGPROC_MORPH_CROSS     ((int32_t)1)
#define OPENCV_IMGPROC_MORPH_ELLIPSE   ((int32_t)2)

#define OPENCV_IMGPROC_MORPH_OPEN      ((int32_t)0)
#define OPENCV_IMGPROC_MORPH_CLOSE     ((int32_t)1)
#define OPENCV_IMGPROC_MORPH_GRADIENT  ((int32_t)2)
#define OPENCV_IMGPROC_MORPH_TOP_HAT   ((int32_t)3)
#define OPENCV_IMGPROC_MORPH_BLACK_HAT ((int32_t)4)

#define OPENCV_IMGPROC_CANNY_APERTURE_3 ((int32_t)0)
#define OPENCV_IMGPROC_CANNY_APERTURE_5 ((int32_t)1)
#define OPENCV_IMGPROC_CANNY_APERTURE_7 ((int32_t)2)

#define OPENCV_IMGPROC_CANNY_GRADIENT_L1 ((int32_t)0)
#define OPENCV_IMGPROC_CANNY_GRADIENT_L2 ((int32_t)1)

#define OPENCV_IMGPROC_THRESHOLD_BINARY          ((int32_t)0)
#define OPENCV_IMGPROC_THRESHOLD_BINARY_INVERSE  ((int32_t)1)
#define OPENCV_IMGPROC_THRESHOLD_TRUNCATE        ((int32_t)2)
#define OPENCV_IMGPROC_THRESHOLD_TO_ZERO         ((int32_t)3)
#define OPENCV_IMGPROC_THRESHOLD_TO_ZERO_INVERSE ((int32_t)4)

#define OPENCV_IMGPROC_AUTO_THRESHOLD_OTSU     ((int32_t)0)
#define OPENCV_IMGPROC_AUTO_THRESHOLD_TRIANGLE ((int32_t)1)

#define OPENCV_IMGPROC_DERIVATIVE_SAME_DEPTH ((int32_t)0)
#define OPENCV_IMGPROC_DERIVATIVE_INT16      ((int32_t)1)
#define OPENCV_IMGPROC_DERIVATIVE_FLOAT32    ((int32_t)2)
#define OPENCV_IMGPROC_DERIVATIVE_FLOAT64    ((int32_t)3)

#define OPENCV_IMGPROC_SOBEL_KERNEL_1 ((int32_t)1)
#define OPENCV_IMGPROC_SOBEL_KERNEL_3 ((int32_t)3)
#define OPENCV_IMGPROC_SOBEL_KERNEL_5 ((int32_t)5)
#define OPENCV_IMGPROC_SOBEL_KERNEL_7 ((int32_t)7)

#define OPENCV_IMGPROC_DERIVATIVE_X ((int32_t)0)
#define OPENCV_IMGPROC_DERIVATIVE_Y ((int32_t)1)

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

opencv_imgproc_status
opencv_imgproc_gaussian_blur(
    const opencv_core_mat_handle *source,
    opencv_core_mat_handle *destination,
    int32_t kernel_width,
    int32_t kernel_height,
    double sigma,
    int32_t border);

opencv_imgproc_status
opencv_imgproc_erode(
    const opencv_core_mat_handle *source,
    opencv_core_mat_handle *destination,
    int32_t kernel_width,
    int32_t kernel_height,
    int32_t shape,
    int32_t iterations,
    int32_t border);

opencv_imgproc_status
opencv_imgproc_dilate(
    const opencv_core_mat_handle *source,
    opencv_core_mat_handle *destination,
    int32_t kernel_width,
    int32_t kernel_height,
    int32_t shape,
    int32_t iterations,
    int32_t border);

opencv_imgproc_status
opencv_imgproc_morphology_ex(
    const opencv_core_mat_handle *source,
    opencv_core_mat_handle *destination,
    int32_t operation,
    int32_t kernel_width,
    int32_t kernel_height,
    int32_t shape,
    int32_t iterations,
    int32_t border);

opencv_imgproc_status
opencv_imgproc_canny(
    const opencv_core_mat_handle *source,
    opencv_core_mat_handle *destination,
    double lower_threshold,
    double upper_threshold,
    int32_t aperture,
    int32_t gradient_norm);

opencv_imgproc_status
opencv_imgproc_threshold(
    const opencv_core_mat_handle *source,
    opencv_core_mat_handle *destination,
    double threshold_value,
    double maximum_value,
    int32_t mode);

opencv_imgproc_status
opencv_imgproc_automatic_threshold(
    const opencv_core_mat_handle *source,
    opencv_core_mat_handle *destination,
    double maximum_value,
    int32_t method,
    int32_t mode,
    double *computed_threshold);

opencv_imgproc_status
opencv_imgproc_sobel(
    const opencv_core_mat_handle *source,
    opencv_core_mat_handle *destination,
    int32_t destination_depth,
    int32_t x_order,
    int32_t y_order,
    int32_t kernel_size,
    double scale,
    double delta,
    int32_t border);

opencv_imgproc_status
opencv_imgproc_scharr(
    const opencv_core_mat_handle *source,
    opencv_core_mat_handle *destination,
    int32_t destination_depth,
    int32_t axis,
    double scale,
    double delta,
    int32_t border);

#ifdef __cplusplus
}
#endif

#endif
