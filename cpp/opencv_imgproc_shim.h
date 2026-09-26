#ifndef OPENCV_IMGPROC_SHIM_H
#define OPENCV_IMGPROC_SHIM_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct opencv_core_mat_handle opencv_core_mat_handle;
typedef struct opencv_imgproc_contours_handle opencv_imgproc_contours_handle;
typedef struct opencv_imgproc_hough_lines_handle
    opencv_imgproc_hough_lines_handle;
typedef struct opencv_imgproc_hough_segments_handle
    opencv_imgproc_hough_segments_handle;
typedef struct opencv_imgproc_hough_circles_handle
    opencv_imgproc_hough_circles_handle;

typedef struct {
    int32_t x;
    int32_t y;
} opencv_imgproc_point_i32;

/* Polar standard-Hough line: rho in pixels, theta in radians. */
typedef struct {
    float rho;
    float theta;
} opencv_imgproc_hough_line;

/* Probabilistic-Hough segment endpoints (x1, y1) and (x2, y2). */
typedef struct {
    int32_t x1;
    int32_t y1;
    int32_t x2;
    int32_t y2;
} opencv_imgproc_hough_segment;

/* Gradient-Hough circle center and radius in pixels. */
typedef struct {
    float x;
    float y;
    float radius;
} opencv_imgproc_hough_circle;

typedef int32_t opencv_imgproc_status;

#define OPENCV_IMGPROC_OK                     ((opencv_imgproc_status)0)
#define OPENCV_IMGPROC_ERROR_OPENCV           ((opencv_imgproc_status)1)
#define OPENCV_IMGPROC_ERROR_STD              ((opencv_imgproc_status)2)
#define OPENCV_IMGPROC_ERROR_UNKNOWN          ((opencv_imgproc_status)3)
#define OPENCV_IMGPROC_ERROR_INVALID_ARGUMENT ((opencv_imgproc_status)4)

/* Semantic selectors: 0=L1, 1=chessboard, 2=L2 3x3,
 * 3=L2 5x5, 4=L2 precise; labeled metric 0=L1, 1=L2, 2=C;
 * label mode 0=8-connected zero components, 1=individual zero pixels. */
opencv_imgproc_status opencv_imgproc_distance_transform_f32(
    const opencv_core_mat_handle *source, int32_t method,
    opencv_core_mat_handle *destination);
opencv_imgproc_status opencv_imgproc_distance_transform_l1_u8(
    const opencv_core_mat_handle *source, opencv_core_mat_handle *destination);
opencv_imgproc_status opencv_imgproc_distance_transform_labeled(
    const opencv_core_mat_handle *source, int32_t metric, int32_t label_mode,
    opencv_core_mat_handle *distances, opencv_core_mat_handle *labels);

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

#define OPENCV_IMGPROC_WARP_INTER_NEAREST ((int32_t)0)
#define OPENCV_IMGPROC_WARP_INTER_LINEAR  ((int32_t)1)

#define OPENCV_IMGPROC_WARP_MAPPING_SOURCE_TO_DESTINATION ((int32_t)0)
#define OPENCV_IMGPROC_WARP_MAPPING_DESTINATION_TO_SOURCE ((int32_t)1)

#define OPENCV_IMGPROC_LINE_4  ((int32_t)0)
#define OPENCV_IMGPROC_LINE_8  ((int32_t)1)
#define OPENCV_IMGPROC_LINE_AA ((int32_t)2)

#define OPENCV_IMGPROC_DRAW_OUTLINE ((int32_t)0)
#define OPENCV_IMGPROC_DRAW_FILLED  ((int32_t)1)

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
opencv_imgproc_equalize_histogram(
    const opencv_core_mat_handle *source,
    opencv_core_mat_handle *destination);

opencv_imgproc_status
opencv_imgproc_clahe(
    const opencv_core_mat_handle *source,
    opencv_core_mat_handle *destination,
    double clip_limit,
    int32_t tile_grid_width,
    int32_t tile_grid_height);

opencv_imgproc_status
opencv_imgproc_connected_components_with_stats(
    const opencv_core_mat_handle *source,
    opencv_core_mat_handle *labels,
    opencv_core_mat_handle *stats,
    opencv_core_mat_handle *centroids,
    int32_t connectivity,
    int32_t *label_count);

opencv_imgproc_status
opencv_imgproc_mats_overlap(
    const opencv_core_mat_handle *first,
    const opencv_core_mat_handle *second,
    uint8_t *overlap);

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

/*
 * Hough detection. Each detector snapshots (clones) the borrowed source
 * before invoking OpenCV, so caller pixels are never passed to an
 * implementation documented as allowed to modify them, and a Mat view is
 * processed as its own logical image. *out_result is null on failure. A
 * successful result is owned by the caller and must be released with the
 * matching destroy function, which accepts null. Copy functions require a
 * nonnegative capacity of at least the result count and write nothing on
 * failure.
 */

#define OPENCV_IMGPROC_HOUGH_RADIUS_AUTOMATIC ((int32_t)0)
#define OPENCV_IMGPROC_HOUGH_RADIUS_EXPLICIT  ((int32_t)1)

opencv_imgproc_status
opencv_imgproc_hough_lines(
    const opencv_core_mat_handle *source,
    double rho,
    double theta,
    int32_t threshold,
    double min_theta,
    double max_theta,
    opencv_imgproc_hough_lines_handle **out_result);

void
opencv_imgproc_hough_lines_destroy(opencv_imgproc_hough_lines_handle *result);

opencv_imgproc_status
opencv_imgproc_hough_lines_count(
    const opencv_imgproc_hough_lines_handle *result,
    int32_t *out_count);

opencv_imgproc_status
opencv_imgproc_hough_lines_copy(
    const opencv_imgproc_hough_lines_handle *result,
    opencv_imgproc_hough_line *lines,
    int32_t capacity);

opencv_imgproc_status
opencv_imgproc_hough_segments(
    const opencv_core_mat_handle *source,
    double rho,
    double theta,
    int32_t threshold,
    int32_t min_line_length,
    int32_t max_line_gap,
    opencv_imgproc_hough_segments_handle **out_result);

void
opencv_imgproc_hough_segments_destroy(
    opencv_imgproc_hough_segments_handle *result);

opencv_imgproc_status
opencv_imgproc_hough_segments_count(
    const opencv_imgproc_hough_segments_handle *result,
    int32_t *out_count);

opencv_imgproc_status
opencv_imgproc_hough_segments_copy(
    const opencv_imgproc_hough_segments_handle *result,
    opencv_imgproc_hough_segment *segments,
    int32_t capacity);

/*
 * radius_mode OPENCV_IMGPROC_HOUGH_RADIUS_AUTOMATIC requires max_radius == 0
 * and lets OpenCV use max(rows, cols). OPENCV_IMGPROC_HOUGH_RADIUS_EXPLICIT
 * requires max_radius > min_radius. OpenCV's negative centers-only sentinel
 * is not reachable through this ABI.
 */
opencv_imgproc_status
opencv_imgproc_hough_circles(
    const opencv_core_mat_handle *source,
    double dp,
    double min_dist,
    int32_t canny_threshold,
    int32_t accumulator_threshold,
    int32_t radius_mode,
    int32_t min_radius,
    int32_t max_radius,
    opencv_imgproc_hough_circles_handle **out_result);

void
opencv_imgproc_hough_circles_destroy(
    opencv_imgproc_hough_circles_handle *result);

opencv_imgproc_status
opencv_imgproc_hough_circles_count(
    const opencv_imgproc_hough_circles_handle *result,
    int32_t *out_count);

opencv_imgproc_status
opencv_imgproc_hough_circles_copy(
    const opencv_imgproc_hough_circles_handle *result,
    opencv_imgproc_hough_circle *circles,
    int32_t capacity);

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

opencv_imgproc_status
opencv_imgproc_warp_affine(
    const opencv_core_mat_handle *source,
    const opencv_core_mat_handle *transform,
    opencv_core_mat_handle *destination,
    int32_t output_width,
    int32_t output_height,
    int32_t interpolation,
    int32_t mapping,
    int32_t border,
    double border_value_0,
    double border_value_1,
    double border_value_2,
    double border_value_3);

opencv_imgproc_status
opencv_imgproc_warp_perspective(
    const opencv_core_mat_handle *source,
    const opencv_core_mat_handle *transform,
    opencv_core_mat_handle *destination,
    int32_t output_width,
    int32_t output_height,
    int32_t interpolation,
    int32_t mapping,
    int32_t border,
    double border_value_0,
    double border_value_1,
    double border_value_2,
    double border_value_3);

opencv_imgproc_status
opencv_imgproc_remap(
    const opencv_core_mat_handle *source,
    const opencv_core_mat_handle *map_x,
    const opencv_core_mat_handle *map_y,
    opencv_core_mat_handle *destination,
    int32_t interpolation,
    int32_t border,
    double border_value_0,
    double border_value_1,
    double border_value_2,
    double border_value_3);

opencv_imgproc_status
opencv_imgproc_draw_line(
    opencv_core_mat_handle *image,
    int32_t start_x,
    int32_t start_y,
    int32_t finish_x,
    int32_t finish_y,
    double color_0,
    double color_1,
    double color_2,
    double color_3,
    int32_t thickness,
    int32_t line_style);

opencv_imgproc_status
opencv_imgproc_draw_rectangle(
    opencv_core_mat_handle *image,
    int32_t origin_x,
    int32_t origin_y,
    int32_t width,
    int32_t height,
    double color_0,
    double color_1,
    double color_2,
    double color_3,
    int32_t filled,
    int32_t thickness,
    int32_t line_style);

opencv_imgproc_status
opencv_imgproc_draw_circle(
    opencv_core_mat_handle *image,
    int32_t center_x,
    int32_t center_y,
    int32_t radius,
    double color_0,
    double color_1,
    double color_2,
    double color_3,
    int32_t filled,
    int32_t thickness,
    int32_t line_style);

opencv_imgproc_status
opencv_imgproc_draw_ellipse(
    opencv_core_mat_handle *image,
    int32_t center_x,
    int32_t center_y,
    int32_t axis_width,
    int32_t axis_height,
    double angle,
    double start_angle,
    double end_angle,
    double color_0,
    double color_1,
    double color_2,
    double color_3,
    int32_t filled,
    int32_t thickness,
    int32_t line_style);

opencv_imgproc_status
opencv_imgproc_draw_polyline(
    opencv_core_mat_handle *image,
    const opencv_imgproc_point_i32 *points,
    int32_t point_count,
    uint8_t closed,
    double color_0,
    double color_1,
    double color_2,
    double color_3,
    int32_t thickness,
    int32_t line_style);

opencv_imgproc_status
opencv_imgproc_fill_polygon(
    opencv_core_mat_handle *image,
    const opencv_imgproc_point_i32 *points,
    int32_t point_count,
    double color_0,
    double color_1,
    double color_2,
    double color_3,
    int32_t line_style);

/* Segmentation. */

/* Four scalar components; channel k uses values[k]. */
typedef struct {
    double values[4];
} opencv_imgproc_scalar4;

/* Axis-aligned integer rectangle. */
typedef struct {
    int32_t x;
    int32_t y;
    int32_t width;
    int32_t height;
} opencv_imgproc_rect_i32;

#define OPENCV_IMGPROC_FLOOD_FILL_FLOATING_RANGE ((int32_t)0)
#define OPENCV_IMGPROC_FLOOD_FILL_FIXED_RANGE    ((int32_t)1)

/*
 * Flood fill of a UInt8 or Float32 C1/C3 image in place.
 * connectivity is 4 or 8; range_mode is one of the FLOOD_FILL constants;
 * mask_fill_value must be 1..255; mask_only is 0 or 1. On success
 * pixel_count and bounds receive OpenCV's area and bounding rectangle. On
 * failure they are zero. The unmasked form lets OpenCV use a private mask.
 */
opencv_imgproc_status
opencv_imgproc_flood_fill(
    opencv_core_mat_handle *image,
    int32_t seed_x,
    int32_t seed_y,
    const opencv_imgproc_scalar4 *new_value,
    const opencv_imgproc_scalar4 *lower_difference,
    const opencv_imgproc_scalar4 *upper_difference,
    int32_t connectivity,
    int32_t range_mode,
    int32_t *pixel_count,
    opencv_imgproc_rect_i32 *bounds);

/*
 * As opencv_imgproc_flood_fill with a caller-supplied UInt8 C1 mask of
 * (rows + 2) x (cols + 2). Image (x, y) corresponds to mask (x + 1, y + 1).
 * Image and mask storage must not overlap.
 */
opencv_imgproc_status
opencv_imgproc_flood_fill_masked(
    opencv_core_mat_handle *image,
    opencv_core_mat_handle *mask,
    int32_t seed_x,
    int32_t seed_y,
    const opencv_imgproc_scalar4 *new_value,
    const opencv_imgproc_scalar4 *lower_difference,
    const opencv_imgproc_scalar4 *upper_difference,
    int32_t connectivity,
    int32_t range_mode,
    int32_t mask_fill_value,
    uint8_t mask_only,
    int32_t *pixel_count,
    opencv_imgproc_rect_i32 *bounds);

/* Marker-based watershed. source is UInt8 C3; markers is Int32 C1 of the
 * same size and is updated in place. Storage must not overlap. */
opencv_imgproc_status
opencv_imgproc_watershed(
    const opencv_core_mat_handle *source,
    opencv_core_mat_handle *markers);

#define OPENCV_IMGPROC_GRABCUT_INIT_WITH_RECT    ((int32_t)0)
#define OPENCV_IMGPROC_GRABCUT_INIT_WITH_MASK    ((int32_t)1)
#define OPENCV_IMGPROC_GRABCUT_EVAL              ((int32_t)2)
#define OPENCV_IMGPROC_GRABCUT_EVAL_FREEZE_MODEL ((int32_t)3)

/* Portable minimum training-set size: OpenCV 4.1 initializes five-component
 * GMMs with kmeans(K = 5), which requires at least five samples. */
#define OPENCV_IMGPROC_GRABCUT_MINIMUM_TRAINING_SAMPLES ((int32_t)5)

/*
 * GrabCut. source is UInt8 C3. mask, background_model, and foreground_model
 * are distinct, non-overlapping state Mats updated in place. The rectangle
 * is used only by INIT_WITH_RECT. Initialization modes require at least
 * five background and five foreground training pixels. Evaluation modes
 * require Float64 C1 1 x 65 models. iteration_count must be positive, and
 * exactly 1 for EVAL_FREEZE_MODEL.
 */
opencv_imgproc_status
opencv_imgproc_grabcut(
    const opencv_core_mat_handle *source,
    opencv_core_mat_handle *mask,
    opencv_core_mat_handle *background_model,
    opencv_core_mat_handle *foreground_model,
    int32_t rect_x,
    int32_t rect_y,
    int32_t rect_width,
    int32_t rect_height,
    int32_t iteration_count,
    int32_t mode);

/* Sets *overlap to 1 when any element byte addressed by one Mat is also
 * addressed by the other, independent of element type or row step, and to 0
 * otherwise. Empty Mats never overlap. Used by segmentation validation. */
opencv_imgproc_status
opencv_imgproc_mat_storage_overlap(
    const opencv_core_mat_handle *first,
    const opencv_core_mat_handle *second,
    uint8_t *overlap);

/* One uniform histogram dimension: zero-based source channel, positive bin
 * count, and the half-open range [lower_bound, upper_bound). */
typedef struct {
    int32_t channel;
    int32_t bin_count;
    float lower_bound;
    float upper_bound;
} opencv_imgproc_histogram_dimension;

/* Portable dense-histogram dimensionality: OpenCV 4.x allows CV_MAX_DIM
 * (32) Mat dimensions, but OpenCV 5.0 limits Mat to MatShape::MAX_DIMS
 * (10). */
#define OPENCV_IMGPROC_HISTOGRAM_MAX_DIMENSIONS ((int32_t)10)

#define OPENCV_IMGPROC_HISTCMP_CORREL     ((int32_t)0)
#define OPENCV_IMGPROC_HISTCMP_CHISQR     ((int32_t)1)
#define OPENCV_IMGPROC_HISTCMP_INTERSECT  ((int32_t)2)
#define OPENCV_IMGPROC_HISTCMP_HELLINGER  ((int32_t)3)
#define OPENCV_IMGPROC_HISTCMP_CHISQR_ALT ((int32_t)4)
#define OPENCV_IMGPROC_HISTCMP_KL_DIV     ((int32_t)5)

/*
 * Dense uniform histogram of one 2-D UInt8, UInt16 or Float32 source.
 * dimension_count is 1 .. OPENCV_IMGPROC_HISTOGRAM_MAX_DIMENSIONS. The
 * Float32 C1 result replaces *histogram only on success. A one-dimensional
 * histogram is always published as bin_count x 1; a two-dimensional one as
 * bins0 x bins1; higher dimensionality as an N-dimensional Mat.
 */
opencv_imgproc_status
opencv_imgproc_calc_hist(
    const opencv_core_mat_handle *source,
    const opencv_imgproc_histogram_dimension *dimensions,
    int32_t dimension_count,
    opencv_core_mat_handle *histogram);

/* As opencv_imgproc_calc_hist, counting only pixels whose UInt8 C1 mask
 * value (same rows and columns as source) is nonzero. */
opencv_imgproc_status
opencv_imgproc_calc_hist_masked(
    const opencv_core_mat_handle *source,
    const opencv_core_mat_handle *mask,
    const opencv_imgproc_histogram_dimension *dimensions,
    int32_t dimension_count,
    opencv_core_mat_handle *histogram);

/* cv::compareHist on two dense Float32 histograms. *result is 0 on
 * failure. */
opencv_imgproc_status
opencv_imgproc_compare_hist(
    const opencv_core_mat_handle *left,
    const opencv_core_mat_handle *right,
    int32_t method,
    double *result);

/*
 * Back projection of source through a histogram shaped exactly as
 * opencv_imgproc_calc_hist publishes it for the same dimension records.
 * The result (source rows x columns, source depth, C1) replaces
 * *destination only on success.
 */
opencv_imgproc_status
opencv_imgproc_calc_back_project(
    const opencv_core_mat_handle *source,
    const opencv_core_mat_handle *histogram,
    const opencv_imgproc_histogram_dimension *dimensions,
    int32_t dimension_count,
    double scale,
    opencv_core_mat_handle *destination);

#ifdef __cplusplus
}
#endif

#endif
