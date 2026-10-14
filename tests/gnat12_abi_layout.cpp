// Compile-only evidence from the actual production C declarations.
// Compare with -gnatR3 output from test_gnat12_language_policy.py.
#include "opencv_imgproc_shim.h"
#include <cstddef>

#define LAYOUT(type, size, alignment) \
    static_assert(sizeof(type) == size); \
    static_assert(alignof(type) == alignment)
#define OFFSET(type, field, offset) static_assert(offsetof(type, field) == offset)

LAYOUT(opencv_imgproc_guil_parameters, 72, 8);
OFFSET(opencv_imgproc_guil_parameters, minimum_angle, 0);
OFFSET(opencv_imgproc_guil_parameters, maximum_angle, 8);
OFFSET(opencv_imgproc_guil_parameters, angle_step, 16);
OFFSET(opencv_imgproc_guil_parameters, minimum_scale, 24);
OFFSET(opencv_imgproc_guil_parameters, maximum_scale, 32);
OFFSET(opencv_imgproc_guil_parameters, scale_step, 40);
OFFSET(opencv_imgproc_guil_parameters, canny_low, 48);
OFFSET(opencv_imgproc_guil_parameters, canny_high, 52);
OFFSET(opencv_imgproc_guil_parameters, angle_threshold, 56);
OFFSET(opencv_imgproc_guil_parameters, scale_threshold, 60);
OFFSET(opencv_imgproc_guil_parameters, position_threshold, 64);
LAYOUT(opencv_imgproc_point_i32, 8, 4);
OFFSET(opencv_imgproc_point_i32, x, 0);
OFFSET(opencv_imgproc_point_i32, y, 4);
LAYOUT(opencv_imgproc_point_f32, 8, 4);
OFFSET(opencv_imgproc_point_f32, x, 0);
OFFSET(opencv_imgproc_point_f32, y, 4);
LAYOUT(opencv_imgproc_hough_line_evidence, 24, 8);
OFFSET(opencv_imgproc_hough_line_evidence, rho, 0);
OFFSET(opencv_imgproc_hough_line_evidence, theta, 8);
OFFSET(opencv_imgproc_hough_line_evidence, votes, 16);
LAYOUT(opencv_imgproc_hough_circle_evidence, 16, 4);
OFFSET(opencv_imgproc_hough_circle_evidence, x, 0);
OFFSET(opencv_imgproc_hough_circle_evidence, y, 4);
OFFSET(opencv_imgproc_hough_circle_evidence, radius, 8);
OFFSET(opencv_imgproc_hough_circle_evidence, votes, 12);
LAYOUT(opencv_imgproc_hough_line, 8, 4);
OFFSET(opencv_imgproc_hough_line, rho, 0);
OFFSET(opencv_imgproc_hough_line, theta, 4);
LAYOUT(opencv_imgproc_hough_segment, 16, 4);
OFFSET(opencv_imgproc_hough_segment, x1, 0);
OFFSET(opencv_imgproc_hough_segment, y1, 4);
OFFSET(opencv_imgproc_hough_segment, x2, 8);
OFFSET(opencv_imgproc_hough_segment, y2, 12);
LAYOUT(opencv_imgproc_hough_circle, 12, 4);
OFFSET(opencv_imgproc_hough_circle, x, 0);
OFFSET(opencv_imgproc_hough_circle, y, 4);
OFFSET(opencv_imgproc_hough_circle, radius, 8);
LAYOUT(opencv_imgproc_hit_or_miss_facts, 5, 1);
OFFSET(opencv_imgproc_hit_or_miss_facts, source_binary, 0);
OFFSET(opencv_imgproc_hit_or_miss_facts, kernel_ternary, 1);
OFFSET(opencv_imgproc_hit_or_miss_facts, has_constraint, 2);
OFFSET(opencv_imgproc_hit_or_miss_facts, all_hits, 3);
OFFSET(opencv_imgproc_hit_or_miss_facts, all_misses, 4);
LAYOUT(opencv_imgproc_contour_span, 8, 4);
OFFSET(opencv_imgproc_contour_span, first_point, 0);
OFFSET(opencv_imgproc_contour_span, point_count, 4);
LAYOUT(opencv_imgproc_scalar4, 32, 8);
OFFSET(opencv_imgproc_scalar4, values, 0);
LAYOUT(opencv_imgproc_rect_i32, 16, 4);
OFFSET(opencv_imgproc_rect_i32, x, 0);
OFFSET(opencv_imgproc_rect_i32, y, 4);
OFFSET(opencv_imgproc_rect_i32, width, 8);
OFFSET(opencv_imgproc_rect_i32, height, 12);
LAYOUT(opencv_imgproc_histogram_dimension, 16, 4);
OFFSET(opencv_imgproc_histogram_dimension, channel, 0);
OFFSET(opencv_imgproc_histogram_dimension, bin_count, 4);
OFFSET(opencv_imgproc_histogram_dimension, lower_bound, 8);
OFFSET(opencv_imgproc_histogram_dimension, upper_bound, 12);
LAYOUT(opencv_imgproc_histogram_source_dimension, 20, 4);
OFFSET(opencv_imgproc_histogram_source_dimension, source_position, 0);
OFFSET(opencv_imgproc_histogram_source_dimension, channel, 4);
OFFSET(opencv_imgproc_histogram_source_dimension, bin_count, 8);
OFFSET(opencv_imgproc_histogram_source_dimension, lower_bound, 12);
OFFSET(opencv_imgproc_histogram_source_dimension, upper_bound, 16);
LAYOUT(opencv_imgproc_histogram_nonuniform_dimension, 24, 8);
OFFSET(opencv_imgproc_histogram_nonuniform_dimension, source_position, 0);
OFFSET(opencv_imgproc_histogram_nonuniform_dimension, channel, 4);
OFFSET(opencv_imgproc_histogram_nonuniform_dimension, bin_count, 8);
OFFSET(opencv_imgproc_histogram_nonuniform_dimension, boundary_offset, 16);
static_assert(sizeof(int32_t) == 4 && sizeof(uint64_t) == 8);
static_assert(sizeof(float) == 4 && sizeof(double) == 8 && sizeof(void *) == 8);
// C array stride is sizeof(element); scalar4 contains four contiguous doubles.
static_assert(sizeof(((opencv_imgproc_scalar4 *)nullptr)->values) == 32);