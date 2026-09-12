#ifndef OPENCV_IMGPROC_SHIM_H
#define OPENCV_IMGPROC_SHIM_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct opencv_core_mat_handle opencv_core_mat_handle;
typedef struct opencv_imgproc_contours_handle opencv_imgproc_contours_handle;

typedef struct {
    int32_t x;
    int32_t y;
} opencv_imgproc_point_i32;

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
#define OPENCV_IMGPROC_BORDER_WRAP         ((int32_t)4)

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

#define OPENCV_IMGPROC_ADAPTIVE_THRESHOLD_MEAN     ((int32_t)0)
#define OPENCV_IMGPROC_ADAPTIVE_THRESHOLD_GAUSSIAN ((int32_t)1)

#define OPENCV_IMGPROC_CONTOUR_RETR_EXTERNAL ((int32_t)0)
#define OPENCV_IMGPROC_CONTOUR_RETR_LIST     ((int32_t)1)
#define OPENCV_IMGPROC_CONTOUR_RETR_CCOMP    ((int32_t)2)
#define OPENCV_IMGPROC_CONTOUR_RETR_TREE     ((int32_t)3)

#define OPENCV_IMGPROC_CONTOUR_APPROX_NONE      ((int32_t)0)
#define OPENCV_IMGPROC_CONTOUR_APPROX_SIMPLE    ((int32_t)1)
#define OPENCV_IMGPROC_CONTOUR_APPROX_TC89_L1   ((int32_t)2)
#define OPENCV_IMGPROC_CONTOUR_APPROX_TC89_KCOS ((int32_t)3)

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

#define OPENCV_IMGPROC_GAUSSIAN_KERNEL_FLOAT32 ((int32_t)0)
#define OPENCV_IMGPROC_GAUSSIAN_KERNEL_FLOAT64 ((int32_t)1)

#define OPENCV_IMGPROC_DERIVATIVE_KERNELS_UNNORMALIZED ((int32_t)0)
#define OPENCV_IMGPROC_DERIVATIVE_KERNELS_NORMALIZED   ((int32_t)1)

#define OPENCV_IMGPROC_DERIVATIVE_KERNEL_SCHARR ((int32_t)-1)

#define OPENCV_IMGPROC_TEMPLATE_SQDIFF         ((int32_t)0)
#define OPENCV_IMGPROC_TEMPLATE_SQDIFF_NORMED  ((int32_t)1)
#define OPENCV_IMGPROC_TEMPLATE_CCORR          ((int32_t)2)
#define OPENCV_IMGPROC_TEMPLATE_CCORR_NORMED   ((int32_t)3)
#define OPENCV_IMGPROC_TEMPLATE_CCOEFF         ((int32_t)4)
#define OPENCV_IMGPROC_TEMPLATE_CCOEFF_NORMED  ((int32_t)5)

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
opencv_imgproc_get_gaussian_kernel(
    opencv_core_mat_handle *destination,
    int32_t kernel_size,
    double sigma,
    int32_t kernel_depth);

opencv_imgproc_status
opencv_imgproc_get_derivative_kernels(
    opencv_core_mat_handle *kernel_x,
    opencv_core_mat_handle *kernel_y,
    int32_t x_order,
    int32_t y_order,
    int32_t kernel_size,
    int32_t normalize,
    int32_t kernel_depth);

opencv_imgproc_status
opencv_imgproc_median_blur(
    const opencv_core_mat_handle *source,
    opencv_core_mat_handle *destination,
    int32_t kernel_size);

opencv_imgproc_status
opencv_imgproc_box_blur(
    const opencv_core_mat_handle *source,
    opencv_core_mat_handle *destination,
    int32_t kernel_width,
    int32_t kernel_height,
    int32_t border);

opencv_imgproc_status
opencv_imgproc_bilateral_filter(
    const opencv_core_mat_handle *source,
    opencv_core_mat_handle *destination,
    int32_t diameter,
    double sigma_color,
    double sigma_space,
    int32_t border);

opencv_imgproc_status
opencv_imgproc_filter_2d(
    const opencv_core_mat_handle *source,
    opencv_core_mat_handle *destination,
    const opencv_core_mat_handle *kernel,
    int32_t destination_depth,
    int32_t anchor_x,
    int32_t anchor_y,
    double offset,
    int32_t border);

opencv_imgproc_status
opencv_imgproc_sep_filter_2d(
    const opencv_core_mat_handle *source,
    opencv_core_mat_handle *destination,
    const opencv_core_mat_handle *kernel_x,
    const opencv_core_mat_handle *kernel_y,
    int32_t destination_depth,
    int32_t anchor_x,
    int32_t anchor_y,
    double offset,
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
opencv_imgproc_adaptive_threshold(
    const opencv_core_mat_handle *source,
    opencv_core_mat_handle *destination,
    int32_t maximum_value,
    int32_t adaptive_method,
    int32_t threshold_mode,
    int32_t block_size,
    double bias);

opencv_imgproc_status
opencv_imgproc_find_contours(
    const opencv_core_mat_handle *source,
    int32_t retrieval_mode,
    int32_t approximation_mode,
    int32_t offset_x,
    int32_t offset_y,
    opencv_imgproc_contours_handle **out_result);

void
opencv_imgproc_contours_destroy(opencv_imgproc_contours_handle *result);

opencv_imgproc_status
opencv_imgproc_contour_count(
    const opencv_imgproc_contours_handle *result,
    int32_t *out_count);

opencv_imgproc_status
opencv_imgproc_contour_point_count(
    const opencv_imgproc_contours_handle *result,
    int32_t contour_index,
    int32_t *out_count);

opencv_imgproc_status
opencv_imgproc_contour_copy_points(
    const opencv_imgproc_contours_handle *result,
    int32_t contour_index,
    opencv_imgproc_point_i32 *points,
    int32_t capacity);

opencv_imgproc_status
opencv_imgproc_contour_hierarchy(
    const opencv_imgproc_contours_handle *result,
    int32_t contour_index,
    int32_t *next,
    int32_t *previous,
    int32_t *first_child,
    int32_t *parent);

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

opencv_imgproc_status
opencv_imgproc_laplacian(
    const opencv_core_mat_handle *source,
    opencv_core_mat_handle *destination,
    int32_t destination_depth,
    int32_t kernel_size,
    double scale,
    double offset,
    int32_t border);

opencv_imgproc_status
opencv_imgproc_pyr_down(
    const opencv_core_mat_handle *source,
    opencv_core_mat_handle *destination,
    int32_t border);

opencv_imgproc_status
opencv_imgproc_pyr_up(
    const opencv_core_mat_handle *source,
    opencv_core_mat_handle *destination);

opencv_imgproc_status
opencv_imgproc_match_template(
    const opencv_core_mat_handle *source,
    const opencv_core_mat_handle *templ,
    opencv_core_mat_handle *destination,
    int32_t method);

#ifdef __cplusplus
}
#endif

#endif
