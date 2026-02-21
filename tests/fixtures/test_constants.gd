class_name TestConstants

# 测试常量定义

# ========== 物理参数 ==========

const DEFAULT_FRICTION: float = 5.0
const DEFAULT_RETURN_SPEED: float = 2.0
const DEFAULT_MAX_DISPLACEMENT: float = 5.0

const BALL_MASS: float = 0.0027  # kg
const BALL_RADIUS: float = 0.02  # meters

# ========== 网络参数 ==========

const SERVER_PORT: int = 49555
const CLIENT_PORT: int = 9877
const BINARY_PACKET_SIZE: int = 28  # bytes

# ========== 性能基准 ==========

const TARGET_FPS: int = 60
const TARGET_FRAME_TIME_MS: float = 16.67
const MAX_LATENCY_MS: float = 50.0
const MAX_MEMORY_MB: int = 256
const MAX_STARTUP_TIME_S: float = 3.0

# ========== 测试容差 ==========

const FLOAT_TOLERANCE: float = 0.001
const VECTOR_TOLERANCE: float = 0.01
const QUATERNION_TOLERANCE: float = 0.001
const POSITION_TOLERANCE: float = 0.05  # 5cm

# ========== 校准参数 ==========

const CALIBRATION_STEPS: int = 4
const CALIBRATION_TIMEOUT_S: float = 30.0

# ========== 测试数据路径 ==========

const TEST_DATA_DIR: String = "res://tests/fixtures/data/"
const MOCK_RECORDINGS_DIR: String = "res://tests/fixtures/recordings/"
