pub const VERSION = "0.1.0";

pub const ERROR = struct {
    pub const MISSING_VALUE = "Missing value for argument";
    pub const UNKNOWN_ARGUMENT = "Unknown argument";
    pub const FILE_NOT_FOUND = "File not found";
    pub const PARSE_ERROR = "Failed to parse file";
    pub const MERGE_ERROR = "Failed to merge files";
};

pub const DEFAULT = struct {
    pub const TARGET_DIR = ".";
    pub const RECURSIVE = true;
    pub const PRESERVE_COMMENTS = true;
    pub const SORT_IMPORTS = true;
};
