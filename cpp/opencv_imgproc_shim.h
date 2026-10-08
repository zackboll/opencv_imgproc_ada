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
typedef struct opencv_imgproc_hough_line_evidence_handle
    opencv_imgproc_hough_line_evidence_handle;
typedef struct opencv_imgproc_hough_circle_evidence_handle
    opencv_imgproc_hough_circle_evidence_handle;
typedef struct opencv_imgproc_pyramid_handle opencv_imgproc_pyramid_handle;

typedef struct {
    int32_t x;
    int32_t y;
} opencv_imgproc_point_i32;

typedef struct {
    float x;
    float y;
} opencv_imgproc_point_f32;

/* Polar Hough line with accumulator votes, normalized to (rho, theta,
 * votes) for both raster (native Vec3f) and point-set (native Vec3d
 * (votes, rho, theta)) results. */
typedef struct {
    double rho;
    double theta;
    double votes;
} opencv_imgproc_hough_line_evidence;

/* Radius-finding gradient-Hough circle with its native Vec4f support
 * count. Never produced by centers-only detection. */
typedef struct {
    float x;
    float y;
    float radius;
    float votes;
} opencv_imgproc_hough_circle_evidence;

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

/* Four borrowed read-only inputs. Fresh result is published only on success;
 * a failed call leaves destination unchanged. UInt8 raw weights must be finite
 * in [0,1] to keep native float-to-integer conversion safe. Float32 raw weight
 * values retain native arithmetic; the public weight policy belongs to Ada. */
opencv_imgproc_status opencv_imgproc_blend_linear(
    const opencv_core_mat_handle *source1,
    const opencv_core_mat_handle *source2,
    const opencv_core_mat_handle *weight1,
    const opencv_core_mat_handle *weight2,
    opencv_core_mat_handle *destination);

/* Borrowed Mats, atomic fresh-result publication. Portable selectors 0..19
 * only, in Autumn..Twilight_Shifted order; never native-version expansion.
 * Custom CV_8UC1 LUTs are excluded for cross-version output ABI stability:
 * native 4.1 produces C3 with them, 4.10/5 produce C1. */
opencv_imgproc_status opencv_imgproc_apply_colormap(
    const opencv_core_mat_handle *source, opencv_core_mat_handle *destination,
    int32_t selector);
opencv_imgproc_status opencv_imgproc_apply_custom_colormap(
    const opencv_core_mat_handle *source, opencv_core_mat_handle *destination,
    const opencv_core_mat_handle *lookup_table);

#define OPENCV_IMGPROC_OK                     ((opencv_imgproc_status)0)
#define OPENCV_IMGPROC_ERROR_OPENCV           ((opencv_imgproc_status)1)
#define OPENCV_IMGPROC_ERROR_STD              ((opencv_imgproc_status)2)
#define OPENCV_IMGPROC_ERROR_UNKNOWN          ((opencv_imgproc_status)3)
#define OPENCV_IMGPROC_ERROR_INVALID_ARGUMENT ((opencv_imgproc_status)4)

/* Borrowed inputs, independently cloned before execution. Null window means
 * no window. Scalars and existing output Mats are unchanged on failure.
 * Hanning depth selector: 0=Float32, 1=Float64. */
opencv_imgproc_status opencv_imgproc_phase_correlate(
    const opencv_core_mat_handle *source1,
    const opencv_core_mat_handle *source2,
    const opencv_core_mat_handle *window,
    double *x, double *y, double *response);
opencv_imgproc_status opencv_imgproc_create_hanning_window(
    int32_t width, int32_t height, int32_t depth,
    opencv_core_mat_handle *result);

/* mode: 0=add, 1=square, 2=product, 3=weighted. source2 is required only
 * for product; mask may be null or empty. All handles are borrowed.
 * Result is rebound to a private Base clone only on complete success;
 * on failure its previous header/storage remains unchanged. Weight policy
 * belongs to Ada; raw floating arithmetic (including nonfinite) is native. */
opencv_imgproc_status opencv_imgproc_accumulate_image(
    const opencv_core_mat_handle *source1,
    const opencv_core_mat_handle *source2,
    const opencv_core_mat_handle *base,
    const opencv_core_mat_handle *mask,
    int32_t mode, double weight, opencv_core_mat_handle *result);

/* mode: 0=min eigenvalue, 1=Harris, 2=eigenvalues/vectors, 3=pre-corner.
 * aperture is 3, 5 or 7; border is a semantic border selector. */
opencv_imgproc_status opencv_imgproc_corner_response(
    const opencv_core_mat_handle *source, opencv_core_mat_handle *destination,
    int32_t mode, int32_t block_size, int32_t aperture, double k,
    int32_t border);

/* POD points are explicitly converted to native Point2f. Result is copied
 * only after complete native success; count zero permits null buffers. */
opencv_imgproc_status opencv_imgproc_corner_subpixel(
    const opencv_core_mat_handle *source,
    const opencv_imgproc_point_f32 *points, int32_t count,
    opencv_imgproc_point_f32 *result, int32_t half_width,
    int32_t half_height, int32_t dead_width, int32_t dead_height,
    int32_t iterations, double epsilon);

/* 0=L1, 1=L2, 2=chessboard, 3=explicit Float32 transport costs.
 * Built-in modes ignore cost (which may be null). Scalar and flow are
 * published only on success; a failed flow call leaves its Mat unchanged. */
opencv_imgproc_status opencv_imgproc_earth_mover_distance(
    const opencv_core_mat_handle *signature1,
    const opencv_core_mat_handle *signature2, int32_t metric,
    const opencv_core_mat_handle *cost, float *distance);
opencv_imgproc_status opencv_imgproc_earth_mover_distance_flow(
    const opencv_core_mat_handle *signature1,
    const opencv_core_mat_handle *signature2, int32_t metric,
    const opencv_core_mat_handle *cost, float *distance,
    opencv_core_mat_handle *flow);

/* Built-in metrics only (0..2). Threshold is native Float32 input;
 * lower_bound is a scalar output, not a pointer-valued public abstraction.
 * Flags are 0/1. Unavailable bound is reported as zero, exact as 1.
 * All four outputs are required and left unchanged on failure. */
opencv_imgproc_status opencv_imgproc_earth_mover_distance_lower_bound(
    const opencv_core_mat_handle *signature1,
    const opencv_core_mat_handle *signature2, int32_t metric,
    float initial_threshold, float *distance, float *lower_bound,
    uint8_t *lower_bound_available, uint8_t *exact_distance_computed);

/* Semantic depths: sum 0=Int32, 1=Float32, 2=Float64;
 * square 0=Float32, 1=Float64. Outputs are borrowed Core Mat headers. */
opencv_imgproc_status opencv_imgproc_integral_sum(
    const opencv_core_mat_handle *source, int32_t sum_depth,
    opencv_core_mat_handle *sum);
opencv_imgproc_status opencv_imgproc_integral_sum_squares(
    const opencv_core_mat_handle *source, int32_t sum_depth,
    int32_t squared_depth, opencv_core_mat_handle *sum,
    opencv_core_mat_handle *squared);
opencv_imgproc_status opencv_imgproc_integral_complete(
    const opencv_core_mat_handle *source, int32_t sum_depth,
    int32_t squared_depth, opencv_core_mat_handle *sum,
    opencv_core_mat_handle *squared, opencv_core_mat_handle *tilted);

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
/* Semantic selectors, never OpenCV ColorConversionCodes. */
#define OPENCV_IMGPROC_COLOR_RGB_TO_GRAY ((int32_t)1)
#define OPENCV_IMGPROC_COLOR_BGRA_TO_GRAY ((int32_t)2)
#define OPENCV_IMGPROC_COLOR_RGBA_TO_GRAY ((int32_t)3)
#define OPENCV_IMGPROC_COLOR_GRAY_TO_BGR ((int32_t)4)
#define OPENCV_IMGPROC_COLOR_GRAY_TO_RGB ((int32_t)5)
#define OPENCV_IMGPROC_COLOR_GRAY_TO_BGRA ((int32_t)6)
#define OPENCV_IMGPROC_COLOR_GRAY_TO_RGBA ((int32_t)7)
#define OPENCV_IMGPROC_COLOR_BGR_TO_RGB ((int32_t)8)
#define OPENCV_IMGPROC_COLOR_RGB_TO_BGR ((int32_t)9)
#define OPENCV_IMGPROC_COLOR_BGR_TO_BGRA ((int32_t)10)
#define OPENCV_IMGPROC_COLOR_RGB_TO_RGBA ((int32_t)11)
#define OPENCV_IMGPROC_COLOR_BGR_TO_RGBA ((int32_t)12)
#define OPENCV_IMGPROC_COLOR_RGB_TO_BGRA ((int32_t)13)
#define OPENCV_IMGPROC_COLOR_BGRA_TO_BGR ((int32_t)14)
#define OPENCV_IMGPROC_COLOR_RGBA_TO_RGB ((int32_t)15)
#define OPENCV_IMGPROC_COLOR_RGBA_TO_BGR ((int32_t)16)
#define OPENCV_IMGPROC_COLOR_BGRA_TO_RGB ((int32_t)17)
#define OPENCV_IMGPROC_COLOR_BGRA_TO_RGBA ((int32_t)18)
#define OPENCV_IMGPROC_COLOR_RGBA_TO_BGRA ((int32_t)19)
#define OPENCV_IMGPROC_COLOR_BGR_TO_XYZ ((int32_t)20)
#define OPENCV_IMGPROC_COLOR_RGB_TO_XYZ ((int32_t)21)
#define OPENCV_IMGPROC_COLOR_XYZ_TO_BGR ((int32_t)22)
#define OPENCV_IMGPROC_COLOR_XYZ_TO_RGB ((int32_t)23)
#define OPENCV_IMGPROC_COLOR_BGR_TO_YCRCB ((int32_t)24)
#define OPENCV_IMGPROC_COLOR_RGB_TO_YCRCB ((int32_t)25)
#define OPENCV_IMGPROC_COLOR_YCRCB_TO_BGR ((int32_t)26)
#define OPENCV_IMGPROC_COLOR_YCRCB_TO_RGB ((int32_t)27)
#define OPENCV_IMGPROC_COLOR_BGR_TO_YUV ((int32_t)28)
#define OPENCV_IMGPROC_COLOR_RGB_TO_YUV ((int32_t)29)
#define OPENCV_IMGPROC_COLOR_YUV_TO_BGR ((int32_t)30)
#define OPENCV_IMGPROC_COLOR_YUV_TO_RGB ((int32_t)31)
#define OPENCV_IMGPROC_COLOR_BGR_TO_HSV ((int32_t)32)
#define OPENCV_IMGPROC_COLOR_RGB_TO_HSV ((int32_t)33)
#define OPENCV_IMGPROC_COLOR_HSV_TO_BGR ((int32_t)34)
#define OPENCV_IMGPROC_COLOR_HSV_TO_RGB ((int32_t)35)
#define OPENCV_IMGPROC_COLOR_BGR_TO_HLS ((int32_t)36)
#define OPENCV_IMGPROC_COLOR_RGB_TO_HLS ((int32_t)37)
#define OPENCV_IMGPROC_COLOR_HLS_TO_BGR ((int32_t)38)
#define OPENCV_IMGPROC_COLOR_HLS_TO_RGB ((int32_t)39)
#define OPENCV_IMGPROC_COLOR_BGR_TO_LAB ((int32_t)40)
#define OPENCV_IMGPROC_COLOR_RGB_TO_LAB ((int32_t)41)
#define OPENCV_IMGPROC_COLOR_LAB_TO_BGR ((int32_t)42)
#define OPENCV_IMGPROC_COLOR_LAB_TO_RGB ((int32_t)43)
#define OPENCV_IMGPROC_COLOR_BGR_TO_LUV ((int32_t)44)
#define OPENCV_IMGPROC_COLOR_RGB_TO_LUV ((int32_t)45)
#define OPENCV_IMGPROC_COLOR_LUV_TO_BGR ((int32_t)46)
#define OPENCV_IMGPROC_COLOR_LUV_TO_RGB ((int32_t)47)
#define OPENCV_IMGPROC_COLOR_BGR_TO_BGR565 ((int32_t)48)
#define OPENCV_IMGPROC_COLOR_RGB_TO_BGR565 ((int32_t)49)
#define OPENCV_IMGPROC_COLOR_BGRA_TO_BGR565 ((int32_t)50)
#define OPENCV_IMGPROC_COLOR_RGBA_TO_BGR565 ((int32_t)51)
#define OPENCV_IMGPROC_COLOR_BGR565_TO_BGR ((int32_t)52)
#define OPENCV_IMGPROC_COLOR_BGR565_TO_RGB ((int32_t)53)
#define OPENCV_IMGPROC_COLOR_BGR565_TO_BGRA ((int32_t)54)
#define OPENCV_IMGPROC_COLOR_BGR565_TO_RGBA ((int32_t)55)
#define OPENCV_IMGPROC_COLOR_GRAY_TO_BGR565 ((int32_t)56)
#define OPENCV_IMGPROC_COLOR_BGR565_TO_GRAY ((int32_t)57)
#define OPENCV_IMGPROC_COLOR_BGR_TO_BGR555 ((int32_t)58)
#define OPENCV_IMGPROC_COLOR_RGB_TO_BGR555 ((int32_t)59)
#define OPENCV_IMGPROC_COLOR_BGRA_TO_BGR555 ((int32_t)60)
#define OPENCV_IMGPROC_COLOR_RGBA_TO_BGR555 ((int32_t)61)
#define OPENCV_IMGPROC_COLOR_BGR555_TO_BGR ((int32_t)62)
#define OPENCV_IMGPROC_COLOR_BGR555_TO_RGB ((int32_t)63)
#define OPENCV_IMGPROC_COLOR_BGR555_TO_BGRA ((int32_t)64)
#define OPENCV_IMGPROC_COLOR_BGR555_TO_RGBA ((int32_t)65)
#define OPENCV_IMGPROC_COLOR_GRAY_TO_BGR555 ((int32_t)66)
#define OPENCV_IMGPROC_COLOR_BGR555_TO_GRAY ((int32_t)67)
#define OPENCV_IMGPROC_COLOR_BGR_TO_HSV_FULL ((int32_t)68)
#define OPENCV_IMGPROC_COLOR_RGB_TO_HSV_FULL ((int32_t)69)
#define OPENCV_IMGPROC_COLOR_HSV_FULL_TO_BGR ((int32_t)70)
#define OPENCV_IMGPROC_COLOR_HSV_FULL_TO_RGB ((int32_t)71)
#define OPENCV_IMGPROC_COLOR_BGR_TO_HLS_FULL ((int32_t)72)
#define OPENCV_IMGPROC_COLOR_RGB_TO_HLS_FULL ((int32_t)73)
#define OPENCV_IMGPROC_COLOR_HLS_FULL_TO_BGR ((int32_t)74)
#define OPENCV_IMGPROC_COLOR_HLS_FULL_TO_RGB ((int32_t)75)
#define OPENCV_IMGPROC_COLOR_LINEAR_BGR_TO_LAB ((int32_t)76)
#define OPENCV_IMGPROC_COLOR_LINEAR_RGB_TO_LAB ((int32_t)77)
#define OPENCV_IMGPROC_COLOR_LAB_TO_LINEAR_BGR ((int32_t)78)
#define OPENCV_IMGPROC_COLOR_LAB_TO_LINEAR_RGB ((int32_t)79)
#define OPENCV_IMGPROC_COLOR_LINEAR_BGR_TO_LUV ((int32_t)80)
#define OPENCV_IMGPROC_COLOR_LINEAR_RGB_TO_LUV ((int32_t)81)
#define OPENCV_IMGPROC_COLOR_LUV_TO_LINEAR_BGR ((int32_t)82)
#define OPENCV_IMGPROC_COLOR_LUV_TO_LINEAR_RGB ((int32_t)83)
#define OPENCV_IMGPROC_COLOR_RGBA_TO_PREMULTIPLIED_RGBA ((int32_t)84)
#define OPENCV_IMGPROC_COLOR_PREMULTIPLIED_RGBA_TO_RGBA ((int32_t)85)

#define OPENCV_IMGPROC_INTER_NEAREST  ((int32_t)0)
#define OPENCV_IMGPROC_INTER_LINEAR   ((int32_t)1)
#define OPENCV_IMGPROC_INTER_CUBIC    ((int32_t)2)
#define OPENCV_IMGPROC_INTER_AREA     ((int32_t)3)
#define OPENCV_IMGPROC_INTER_LANCZOS4 ((int32_t)4)
/* Resize only; semantic selectors are not native OpenCV flag values. */
#define OPENCV_IMGPROC_INTER_LINEAR_EXACT ((int32_t)5)

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

/* Private YUV420 selectors: layout 0 I420, 1 YV12, 2 NV12, 3 NV21;
 * output 0 BGR, 1 RGB, 2 BGRA, 3 RGBA; order 0 BGR/BGRA, 1 RGB/RGBA.
 * Two-plane accepts layouts 2..3, encode 0..1. UInt8 sources are snapshotted
 * before native entry. All destinations retain header/storage on failure;
 * same-handle publication is supported. All handles are borrowed from Core.
 */
opencv_imgproc_status opencv_imgproc_decode_yuv420(
    const opencv_core_mat_handle *source, opencv_core_mat_handle *destination,
    int32_t layout, int32_t output);
opencv_imgproc_status opencv_imgproc_decode_yuv420_two_plane(
    const opencv_core_mat_handle *y_plane,
    const opencv_core_mat_handle *uv_plane, opencv_core_mat_handle *destination,
    int32_t layout, int32_t output);
opencv_imgproc_status opencv_imgproc_encode_yuv420_planar(
    const opencv_core_mat_handle *source, opencv_core_mat_handle *destination,
    int32_t layout, int32_t order);
opencv_imgproc_status opencv_imgproc_extract_yuv420_luma(
    const opencv_core_mat_handle *source, opencv_core_mat_handle *destination);

/* Private YUV422: layout 0 UYVY, 1 YUY2, 2 YVYU;
 * output 0 BGR, 1 RGB, 2 BGRA, 3 RGBA. Borrowed UInt8 C2 sources are
 * manually snapshotted. Failure preserves destination header/pixels/storage;
 * same-handle publication succeeds. Raw luma does not require even width.
 */
opencv_imgproc_status opencv_imgproc_decode_yuv422(
    const opencv_core_mat_handle *source, opencv_core_mat_handle *destination,
    int32_t layout, int32_t output);
opencv_imgproc_status opencv_imgproc_extract_yuv422_luma(
    const opencv_core_mat_handle *source, opencv_core_mat_handle *destination,
    int32_t layout);

/* Private selectors: pattern 0 RGGB, 1 GRBG, 2 BGGR, 3 GBRG;
 * method 0 bilinear, 1 VNG, 2 edge-aware; order 0 BGR, 1 RGB.
 * Source is snapshotted. Destination is rebound only after full success.
 * Raw small images retain native behavior where pointer formation is safe.
 */
opencv_imgproc_status opencv_imgproc_demosaic_bayer(
    const opencv_core_mat_handle *source, opencv_core_mat_handle *destination,
    int32_t pattern, int32_t method, int32_t order);
opencv_imgproc_status opencv_imgproc_demosaic_bayer_gray(
    const opencv_core_mat_handle *source, opencv_core_mat_handle *destination,
    int32_t pattern);
opencv_imgproc_status opencv_imgproc_demosaic_bayer_alpha(
    const opencv_core_mat_handle *source, opencv_core_mat_handle *destination,
    int32_t pattern, int32_t order);

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

/* Borrowed Core output; both generators replace it only on success.
 * Depth uses the existing Gaussian coefficient selectors; shape uses only
 * portable Rectangle/Cross/Ellipse selectors. Anchors are resolved by Ada.
 * Raw malformed anchors are translated through native assertion failures. */
opencv_imgproc_status
opencv_imgproc_get_gabor_kernel(
    opencv_core_mat_handle *destination,
    int32_t width, int32_t height, double sigma, double orientation,
    double wavelength, double aspect_ratio, double phase, int32_t depth);

opencv_imgproc_status
opencv_imgproc_get_structuring_element(
    opencv_core_mat_handle *destination,
    int32_t width, int32_t height, int32_t shape,
    int32_t anchor_x, int32_t anchor_y);

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

/* operation 0=erode, 1=dilate, 2..6=open/close/gradient/top-hat/black-hat.
 * kernel_source 0=generated, 1=custom; explicit_anchor 0=centered, 1=given;
 * explicit_border 0=morphology default, 1=scalar. Scalar is borrowed. */
opencv_imgproc_status opencv_imgproc_morphology_request(
    const opencv_core_mat_handle *source, opencv_core_mat_handle *destination,
    int32_t operation, int32_t kernel_source,
    const opencv_core_mat_handle *kernel, int32_t kernel_width,
    int32_t kernel_height, int32_t shape, int32_t explicit_anchor,
    int32_t anchor_x, int32_t anchor_y, int32_t iterations, int32_t border,
    int32_t explicit_border, const double *border_components);

/* Logical-row inspection only: each fact is 0=false or 1=true. Semantic
 * rejection belongs to Ada. Output is cleared on failure. Handles borrowed. */
typedef struct opencv_imgproc_hit_or_miss_facts {
    uint8_t source_binary;
    uint8_t kernel_ternary;
    uint8_t has_constraint;
    uint8_t all_hits;
    uint8_t all_misses;
} opencv_imgproc_hit_or_miss_facts;

opencv_imgproc_status opencv_imgproc_hit_or_miss_inspect(
    const opencv_core_mat_handle *source, const opencv_core_mat_handle *kernel,
    opencv_imgproc_hit_or_miss_facts *facts);

/* Native Hit-or-Miss. Semantic-only inputs outside Ada's contract retain
 * native behavior. explicit_anchor 0=centered, 1=given. No border scalar. */
opencv_imgproc_status opencv_imgproc_hit_or_miss(
    const opencv_core_mat_handle *source, opencv_core_mat_handle *destination,
    const opencv_core_mat_handle *kernel, int32_t explicit_anchor,
    int32_t anchor_x, int32_t anchor_y, int32_t iterations, int32_t border);

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
#define OPENCV_IMGPROC_HOUGH_RADIUS_CENTERS_ONLY ((int32_t)2)

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
 * Standard Hough lines with accumulator votes. Same source and geometry
 * contract as opencv_imgproc_hough_lines, but OpenCV is asked for a fixed
 * Vec3f (rho, theta, votes) output, which never takes the Vec2f-only IPP
 * branch; results may therefore differ in order or content from
 * opencv_imgproc_hough_lines on IPP-enabled builds.
 */
opencv_imgproc_status
opencv_imgproc_hough_lines_with_votes(
    const opencv_core_mat_handle *source,
    double rho,
    double theta,
    int32_t threshold,
    double min_theta,
    double max_theta,
    opencv_imgproc_hough_line_evidence_handle **out_result);

/*
 * cv::HoughLinesPointSet over point_count binary32 points. point_count must
 * be nonnegative and points non-null when point_count > 0. As in OpenCV,
 * maximum_lines must be positive and threshold nonnegative (0 is valid),
 * including for an empty point set. Before OpenCV
 * runs, every point/angle vote is checked to land inside the rho
 * accumulator (OpenCV 4.1 performs no such check), so a rho range that does
 * not contain every vote is rejected.
 */
opencv_imgproc_status
opencv_imgproc_hough_lines_point_set(
    const opencv_imgproc_point_f32 *points,
    int32_t point_count,
    int32_t maximum_lines,
    int32_t threshold,
    double min_rho,
    double max_rho,
    double rho_step,
    double min_theta,
    double max_theta,
    double theta_step,
    opencv_imgproc_hough_line_evidence_handle **out_result);

void
opencv_imgproc_hough_line_evidence_destroy(
    opencv_imgproc_hough_line_evidence_handle *result);

opencv_imgproc_status
opencv_imgproc_hough_line_evidence_count(
    const opencv_imgproc_hough_line_evidence_handle *result,
    int32_t *out_count);

opencv_imgproc_status
opencv_imgproc_hough_line_evidence_copy(
    const opencv_imgproc_hough_line_evidence_handle *result,
    opencv_imgproc_hough_line_evidence *lines,
    int32_t capacity);

/*
 * radius_mode OPENCV_IMGPROC_HOUGH_RADIUS_AUTOMATIC requires max_radius == 0
 * and lets OpenCV use max(rows, cols). OPENCV_IMGPROC_HOUGH_RADIUS_EXPLICIT
 * requires max_radius > min_radius. OPENCV_IMGPROC_HOUGH_RADIUS_CENTERS_ONLY
 * requires max_radius == 0 and privately passes OpenCV's negative
 * centers-only sentinel; each result radius is then 0 and carries no
 * meaning. The sentinel itself is never accepted through this ABI.
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

/*
 * Radius-finding gradient Hough circles with native Vec4f support counts.
 * Accepts only the AUTOMATIC and EXPLICIT radius modes: in centers-only mode
 * OpenCV stores an accumulator index, not a vote count, in the fourth
 * component.
 */
opencv_imgproc_status
opencv_imgproc_hough_circles_with_votes(
    const opencv_core_mat_handle *source,
    double dp,
    double min_dist,
    int32_t canny_threshold,
    int32_t accumulator_threshold,
    int32_t radius_mode,
    int32_t min_radius,
    int32_t max_radius,
    opencv_imgproc_hough_circle_evidence_handle **out_result);

void
opencv_imgproc_hough_circle_evidence_destroy(
    opencv_imgproc_hough_circle_evidence_handle *result);

opencv_imgproc_status
opencv_imgproc_hough_circle_evidence_count(
    const opencv_imgproc_hough_circle_evidence_handle *result,
    int32_t *out_count);

opencv_imgproc_status
opencv_imgproc_hough_circle_evidence_copy(
    const opencv_imgproc_hough_circle_evidence_handle *result,
    opencv_imgproc_hough_circle_evidence *circles,
    int32_t capacity);

/* Borrowed nonempty 2-D CV_8UC1 input. Border is the shim's Reflect_101 (3)
 * or Replicate (1) selector. Outputs must be distinct native Mat objects,
 * neither identical to source; previously shared pixel storage is allowed.
 * Both outputs are freshly allocated and published only after all work
 * succeeds. Failure leaves both existing output objects unchanged.
 * Width one is privately duplicated to width two before native execution. */
opencv_imgproc_status
opencv_imgproc_spatial_gradient(
    const opencv_core_mat_handle *source,
    int32_t border,
    opencv_core_mat_handle *x,
    opencv_core_mat_handle *y);

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

/* Upsamples to an explicit width/height accepted by cv::pyrUp. The result is
 * computed into fresh storage and bound to destination only on success, so
 * destination may share source storage and is unchanged on failure. */
opencv_imgproc_status
opencv_imgproc_pyr_up_sized(
    const opencv_core_mat_handle *source,
    opencv_core_mat_handle *destination,
    int32_t width,
    int32_t height);

/* Builds level_count Gaussian levels (level 0 is the logical source) into a
 * new owned result. *result is null on failure. level_count must lie in
 * 1 .. distinct natural levels of source. */
opencv_imgproc_status
opencv_imgproc_build_pyramid(
    const opencv_core_mat_handle *source,
    int32_t level_count,
    int32_t border,
    opencv_imgproc_pyramid_handle **result);

/* cv::pyrMeanShiftFiltering on a private packed clone of a nonempty 2-D
 * CV_8UC3 source, always with MAX_ITER | EPS termination. The result is
 * computed into fresh storage and bound to destination only on success, so
 * destination may alias or overlap source and is unchanged on failure.
 * maximum_pyramid_level must lie in 0 .. 8 and every generated level must
 * remain at least 2 x 2; maximum_iterations in 1 .. 100; epsilon finite and
 * nonnegative; radii finite. Requests whose native signed-int radius
 * rounding, row offsets, accumulators, or stop expression could overflow are
 * rejected before native execution. */
opencv_imgproc_status
opencv_imgproc_pyr_mean_shift_filter(
    const opencv_core_mat_handle *source,
    opencv_core_mat_handle *destination,
    double spatial_radius,
    double color_radius,
    int32_t maximum_pyramid_level,
    int32_t maximum_iterations,
    double epsilon);

/* Null-safe. */
void
opencv_imgproc_pyramid_destroy(opencv_imgproc_pyramid_handle *result);

opencv_imgproc_status
opencv_imgproc_pyramid_count(
    const opencv_imgproc_pyramid_handle *result,
    int32_t *count);

/* Binds destination to an independent deep copy of level index. Destination
 * is unchanged on failure. */
opencv_imgproc_status
opencv_imgproc_pyramid_copy_level(
    const opencv_imgproc_pyramid_handle *result,
    int32_t index,
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

opencv_imgproc_status opencv_imgproc_warp_polar(
    const opencv_core_mat_handle *source,
    opencv_core_mat_handle *destination,
    float center_x, float center_y, double maximum_radius,
    int32_t output_width, int32_t output_height,
    int32_t mapping, int32_t direction, int32_t interpolation);

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

/* Semantic map modes: 0 interleaved float, 1 fixed. */
opencv_imgproc_status opencv_imgproc_remap_encoded(
    const opencv_core_mat_handle *source,
    const opencv_core_mat_handle *map1,
    const opencv_core_mat_handle *map2,
    opencv_core_mat_handle *destination,
    int32_t mode, int32_t interpolation, int32_t border,
    double border_value_0, double border_value_1,
    double border_value_2, double border_value_3);

/* Semantic conversions: 0 separate->fixed, 1 interleaved->fixed,
   2 fixed->interleaved, 3 fixed->separate,
   4 separate->interleaved, 5 interleaved->separate. */
opencv_imgproc_status opencv_imgproc_convert_remap_maps(
    const opencv_core_mat_handle *map1,
    const opencv_core_mat_handle *map2,
    opencv_core_mat_handle *output1,
    opencv_core_mat_handle *output2,
    int32_t mode, int32_t nearest_only);

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

/* Text is a byte span: null is allowed only when length is zero. */
opencv_imgproc_status opencv_imgproc_draw_arrow(
    opencv_core_mat_handle *image, int32_t start_x, int32_t start_y,
    int32_t finish_x, int32_t finish_y, double color_0, double color_1,
    double color_2, double color_3, double tip_length, int32_t thickness,
    int32_t line_style);
opencv_imgproc_status opencv_imgproc_draw_marker(
    opencv_core_mat_handle *image, int32_t x, int32_t y,
    double color_0, double color_1, double color_2, double color_3,
    int32_t marker, int32_t marker_size, int32_t thickness,
    int32_t line_style);
opencv_imgproc_status opencv_imgproc_draw_text(
    opencv_core_mat_handle *image, const char *text, int32_t text_length,
    int32_t x, int32_t y, double color_0, double color_1,
    double color_2, double color_3, int32_t font, double font_scale,
    int32_t thickness,
    uint8_t bottom_left_origin);
opencv_imgproc_status opencv_imgproc_measure_text(
    const char *text, int32_t text_length, int32_t font, double font_scale,
    int32_t thickness, int32_t *width, int32_t *height,
    int32_t *baseline);
opencv_imgproc_status opencv_imgproc_font_scale_for_height(
    int32_t pixel_height, int32_t font,
    int32_t thickness, double *scale);

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

/* Flat, already selected contours. Spans refer to elements of points. */
typedef struct {
    int32_t first_point;
    int32_t point_count;
} opencv_imgproc_contour_span;

opencv_imgproc_status opencv_imgproc_draw_contours(
    opencv_core_mat_handle *image,
    const opencv_imgproc_point_i32 *points,
    int32_t point_count,
    const opencv_imgproc_contour_span *contours,
    int32_t contour_count,
    double color_0, double color_1, double color_2, double color_3,
    uint8_t filled, int32_t thickness, int32_t line_style,
    int32_t offset_x, int32_t offset_y);

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

/* Read-only structural and payload validation for an imported GrabCut GMM. */
opencv_imgproc_status
opencv_imgproc_validate_grabcut_model(
    const opencv_core_mat_handle *model);

/* Sets *overlap to 1 when any element byte addressed by one Mat is also
 * addressed by the other, independent of element type or row step, and to 0
 * otherwise. Empty Mats never overlap. Used by segmentation validation. */
opencv_imgproc_status
opencv_imgproc_mat_storage_overlap(
    const opencv_core_mat_handle *first,
    const opencv_core_mat_handle *second,
    uint8_t *overlap);

/* One uniform histogram dimension: zero-based source channel, positive bin
 * count, and the half-open range [lower_bound, upper_bound). Source position
 * is implicitly 0. */
typedef struct {
    int32_t channel;
    int32_t bin_count;
    float lower_bound;
    float upper_bound;
} opencv_imgproc_histogram_dimension;

/* One uniform axis of a multi-source histogram. source_position is the
 * zero-based index into the source-handle span (iteration order). channel is
 * zero-based within that source, not a concatenated native channel number. */
typedef struct {
    int32_t source_position;
    int32_t channel;
    int32_t bin_count;
    float lower_bound;
    float upper_bound;
} opencv_imgproc_histogram_source_dimension;

/* One nonuniform axis. boundary_offset is the index of this axis's first
 * edge in the flat boundary buffer passed with the call. The axis consumes
 * exactly bin_count + 1 strictly increasing Float32 edges. */
typedef struct {
    int32_t source_position;
    int32_t channel;
    int32_t bin_count;
    uint64_t boundary_offset;
} opencv_imgproc_histogram_nonuniform_dimension;

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

/*
 * Dense uniform joint histogram of source_count images. Every source must
 * share rows, columns and depth (UInt8, UInt16 or Float32); channel counts
 * may differ. Each dimension selects (source_position, channel). The Float32
 * C1 result replaces *histogram only on success. accumulate is always false.
 */
opencv_imgproc_status
opencv_imgproc_calc_hist_multi(
    const opencv_core_mat_handle *const *sources,
    int32_t source_count,
    const opencv_imgproc_histogram_source_dimension *dimensions,
    int32_t dimension_count,
    opencv_core_mat_handle *histogram);

/* As opencv_imgproc_calc_hist_multi, counting only locations whose UInt8 C1
 * mask (common source geometry) is nonzero. */
opencv_imgproc_status
opencv_imgproc_calc_hist_multi_masked(
    const opencv_core_mat_handle *const *sources,
    int32_t source_count,
    const opencv_core_mat_handle *mask,
    const opencv_imgproc_histogram_source_dimension *dimensions,
    int32_t dimension_count,
    opencv_core_mat_handle *histogram);

/*
 * Dense nonuniform histogram. uniform is false. Each dimension consumes
 * bin_count + 1 edges from boundaries, starting at boundary_offset. The
 * boundary pointer is borrowed only for the duration of the call. The
 * Float32 C1 result replaces *histogram only on success. accumulate is
 * always false.
 */
opencv_imgproc_status
opencv_imgproc_calc_hist_nonuniform(
    const opencv_core_mat_handle *const *sources,
    int32_t source_count,
    const opencv_core_mat_handle *mask,
    uint8_t masked,
    const opencv_imgproc_histogram_nonuniform_dimension *dimensions,
    int32_t dimension_count,
    const float *boundaries,
    uint64_t boundary_count,
    opencv_core_mat_handle *histogram);

/*
 * Nonuniform back projection. uniform is false. Boundaries are the edges
 * stored with the histogram; callers do not resupply a separate range.
 * The result has sources[0]'s rows, columns and depth, and one channel.
 */
opencv_imgproc_status
opencv_imgproc_calc_back_project_nonuniform(
    const opencv_core_mat_handle *const *sources,
    int32_t source_count,
    const opencv_core_mat_handle *histogram,
    const opencv_imgproc_histogram_nonuniform_dimension *dimensions,
    int32_t dimension_count,
    const float *boundaries,
    uint64_t boundary_count,
    double scale,
    opencv_core_mat_handle *destination);

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

/*
 * Back projection of a source span through the same source/channel records
 * used by opencv_imgproc_calc_hist_multi. The result has sources[0]'s rows,
 * columns and depth, and one channel. It replaces *destination only on
 * success.
 */
opencv_imgproc_status
opencv_imgproc_calc_back_project_multi(
    const opencv_core_mat_handle *const *sources,
    int32_t source_count,
    const opencv_core_mat_handle *histogram,
    const opencv_imgproc_histogram_source_dimension *dimensions,
    int32_t dimension_count,
    double scale,
    opencv_core_mat_handle *destination);

/*
 * Elementwise Float32 sum of two nonempty C1 histograms with identical exact
 * shape. Every bin must be finite and nonnegative, and every widened sum must
 * be a finite Float32. *result is bound only after every bin succeeds.
 * This is the portable substitute for calcHist(..., accumulate=true).
 */
opencv_imgproc_status
opencv_imgproc_add_histograms(
    const opencv_core_mat_handle *base,
    const opencv_core_mat_handle *increment,
    opencv_core_mat_handle *result);

/* Borrowed source; destination is rebound only after complete success.
 * output_depth: 0 preserve, 1 Float32. Center is logical-image binary32.
 */
opencv_imgproc_status
opencv_imgproc_extract_subpixel_patch(
    const opencv_core_mat_handle *source, int32_t width, int32_t height,
    float center_x, float center_y, int32_t output_depth,
    opencv_core_mat_handle *destination);

#ifdef __cplusplus
}
#endif

#endif
