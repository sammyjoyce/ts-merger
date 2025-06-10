const std = @import("std");
const Logger = @import("log.zig").Logger;

/// ProgressReporter provides functionality for reporting progress during long-running operations.
/// It can display progress bars, percentage completion, and estimated time remaining.
pub const ProgressReporter = struct {
    allocator: std.mem.Allocator,
    total_steps: usize,
    current_step: usize,
    start_time: i64,
    last_update_time: i64,
    update_interval_ms: i64,
    task_name: []const u8,
    logger: Logger,
    show_progress_bar: bool,

    /// Initialize a new ProgressReporter with the given parameters
    pub fn init(
        allocator: std.mem.Allocator,
        total_steps: usize,
        task_name: []const u8,
        log_level: Logger.LogLevel,
        show_progress_bar: bool,
    ) !*ProgressReporter {
        const self = try allocator.create(ProgressReporter);
        self.* = .{
            .allocator = allocator,
            .total_steps = total_steps,
            .current_step = 0,
            .start_time = std.time.milliTimestamp(),
            .last_update_time = std.time.milliTimestamp(),
            .update_interval_ms = 100, // Update at most every 100ms to avoid flooding the console
            .task_name = try allocator.dupe(u8, task_name),
            .logger = Logger.scoped(log_level, "progress"),
            .show_progress_bar = show_progress_bar,
        };
        return self;
    }

    /// Free resources used by the ProgressReporter
    pub fn deinit(self: *ProgressReporter) void {
        self.allocator.free(self.task_name);
        self.allocator.destroy(self);
    }

    /// Update the progress and display a progress message if enough time has passed since the last update
    pub fn update(self: *ProgressReporter, step: usize, message: ?[]const u8) void {
        const current_time = std.time.milliTimestamp();
        const time_since_last_update = current_time - self.last_update_time;

        // Only update if this is the first or last step, or if enough time has passed
        if (step == 0 or step == self.total_steps or time_since_last_update >= self.update_interval_ms) {
            self.current_step = step;
            self.last_update_time = current_time;
            self.displayProgress(message);
        }
    }

    /// Increment the current step and display a progress message
    pub fn incrementStep(self: *ProgressReporter, message: ?[]const u8) void {
        self.update(self.current_step + 1, message);
    }

    /// Mark the progress as complete
    pub fn complete(self: *ProgressReporter, message: ?[]const u8) void {
        self.update(self.total_steps, message);
    }

    /// Display the current progress
    fn displayProgress(self: *ProgressReporter, message: ?[]const u8) void {
        const percent = if (self.total_steps > 0)
            @as(f64, @floatFromInt(self.current_step)) / @as(f64, @floatFromInt(self.total_steps)) * 100.0
        else
            0.0;

        const elapsed_ms = std.time.milliTimestamp() - self.start_time;
        const elapsed_sec = @as(f64, @floatFromInt(elapsed_ms)) / 1000.0;

        // Calculate estimated time remaining
        var eta_sec: f64 = 0.0;
        if (self.current_step > 0 and self.current_step < self.total_steps) {
            const steps_remaining = self.total_steps - self.current_step;
            const time_per_step = elapsed_sec / @as(f64, @floatFromInt(self.current_step));
            eta_sec = time_per_step * @as(f64, @floatFromInt(steps_remaining));
        }

        // Format the progress message
        if (self.show_progress_bar) {
            const bar_width = 20;
            const filled_width: usize = @intFromFloat(@round(percent / 100.0 * @as(f64, @floatFromInt(bar_width))));

            var progress_bar = self.allocator.alloc(u8, bar_width) catch return;
            defer self.allocator.free(progress_bar);

            for (0..bar_width) |i| {
                progress_bar[i] = if (i < filled_width) '#' else '-';
            }

            if (message) |msg| {
                self.logger.info("{s}: [{s}] {d:.1}% ({d}/{d}) - {s} (elapsed: {d:.1}s, eta: {d:.1}s)", .{ self.task_name, progress_bar, percent, self.current_step, self.total_steps, msg, elapsed_sec, eta_sec });
            } else {
                self.logger.info("{s}: [{s}] {d:.1}% ({d}/{d}) (elapsed: {d:.1}s, eta: {d:.1}s)", .{ self.task_name, progress_bar, percent, self.current_step, self.total_steps, elapsed_sec, eta_sec });
            }
        } else {
            if (message) |msg| {
                self.logger.info("{s}: {d:.1}% ({d}/{d}) - {s} (elapsed: {d:.1}s, eta: {d:.1}s)", .{ self.task_name, percent, self.current_step, self.total_steps, msg, elapsed_sec, eta_sec });
            } else {
                self.logger.info("{s}: {d:.1}% ({d}/{d}) (elapsed: {d:.1}s, eta: {d:.1}s)", .{ self.task_name, percent, self.current_step, self.total_steps, elapsed_sec, eta_sec });
            }
        }
    }
};
