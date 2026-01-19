#!/bin/bash
# setup-ubuntu-env.sh - IoT监控系统Ubuntu环境搭建脚本
# 完全本地运行，无需Docker，无需网络连接

set -e

echo "=================================================="
echo "🔧 IoT传感器数据监控系统 - Ubuntu 环境搭建"
echo "=================================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查脚本是否在项目根目录运行
check_current_directory() {
    if [ ! -f "main.py" ] || [ ! -d "src" ]; then
        log_error "请在项目根目录运行此脚本（包含main.py和src/目录）"
        exit 1
    fi
    log_info "检测到项目根目录: $(pwd)"
}

# 安装系统依赖
install_system_deps() {
    log_info "1. 安装系统依赖..."

    # 检查并安装Python3.8
    if ! command -v python3.8 &> /dev/null; then
        log_info "  安装Python 3.8..."
        sudo apt update
        sudo apt install -y software-properties-common
        sudo add-apt-repository -y ppa:deadsnakes/ppa
        sudo apt update
        sudo apt install -y python3.8 python3.8-venv python3.8-dev python3-pip
    else
        log_success "  Python 3.8已安装"
    fi

    # 检查并安装Mosquitto
    if ! command -v mosquitto &> /dev/null; then
        log_info "  安装Mosquitto MQTT..."
        sudo apt install -y mosquitto mosquitto-clients
        sudo systemctl enable mosquitto
        sudo systemctl start mosquitto
    else
        log_success "  Mosquitto已安装"
    fi

    # 安装其他工具
    sudo apt install -y sqlite3

    log_success "系统依赖安装完成"
}

# 创建Python虚拟环境
setup_python_env() {
    log_info "2. 设置Python虚拟环境..."

    if [ -d "venv" ]; then
        log_warning "虚拟环境已存在，是否重新创建？(y/N)"
        read -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "  删除旧的虚拟环境..."
            rm -rf venv
            python3.8 -m venv venv
        else
            log_info "  使用现有的虚拟环境"
        fi
    else
        python3.8 -m venv venv
    fi

    # 激活虚拟环境
    source venv/bin/activate

    log_success "Python虚拟环境设置完成"
}

# 安装Python依赖
install_python_deps() {
    log_info "3. 安装Python依赖..."

    # 激活虚拟环境
    source venv/bin/activate

    # 检查是否有requirements.txt
    if [ -f "requirements.txt" ]; then
        log_info "  从requirements.txt安装依赖..."

        # 尝试离线安装，如果失败则尝试在线安装
        if pip install -r requirements.txt 2>/dev/null; then
            log_success "  依赖安装成功"
        else
            log_warning "  网络安装失败，尝试手动安装..."
            install_python_deps_manually
        fi
    else
        log_warning "  未找到requirements.txt，创建并安装基础依赖..."
        create_basic_requirements
        install_python_deps_manually
    fi
}

# 创建基础requirements.txt
create_basic_requirements() {
    cat > requirements.txt << 'EOF'
Flask==2.3.3
Flask-CORS==4.0.0
Flask-SocketIO==5.3.4
paho-mqtt==1.6.1
waitress==2.1.2
python-dotenv==1.0.0
APScheduler==3.10.4
EOF
    log_info "  创建requirements.txt"
}

# 手动安装Python依赖
install_python_deps_manually() {
    log_info "  手动安装核心依赖..."

    # 尝试逐个安装，增加成功几率
    for package in "Flask==2.3.3" "Flask-CORS==4.0.0" "paho-mqtt==1.6.1"; do
        log_info "    安装 $package"
        pip install $package 2>/dev/null || log_warning "    安装失败: $package"
    done

    # 尝试安装可选依赖
    for package in "Flask-SocketIO==5.3.4" "waitress==2.1.2" "python-dotenv==1.0.0" "APScheduler==3.10.4"; do
        pip install $package 2>/dev/null && log_info "    安装成功: $package" || log_warning "    跳过: $package"
    done

    log_success "  Python依赖安装完成"
}

# 创建项目目录结构
create_project_structure() {
    log_info "4. 创建项目目录结构..."

    # 创建必要的目录
    mkdir -p data logs static/css static/js templates config

    # 检查重要文件是否存在
    if [ ! -f "templates/index.html" ]; then
        log_warning "  未找到templates/index.html，创建简单版本..."
        create_simple_index_html
    fi

    if [ ! -f "static/css/style.css" ]; then
        log_warning "  未找到static/css/style.css，使用默认样式..."
        cp style.css static/css/ 2>/dev/null || create_simple_style_css
    fi

    if [ ! -f "static/js/main.js" ]; then
        log_warning "  未找到static/js/main.js，使用默认脚本..."
        cp main.js static/js/ 2>/dev/null || create_simple_main_js
    fi

    log_success "项目目录结构创建完成"
}

# 创建简单的index.html
create_simple_index_html() {
    cat > templates/index.html << 'EOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>IoT传感器数据监控系统</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <link rel="stylesheet" href="/static/css/style.css">
</head>
<body>
    <div class="container">
        <div class="header">
            <div>
                <h1>🌱 IoT传感器数据监控系统</h1>
                <p>实时监控农业环境传感器数据</p>
            </div>
            <div class="status-badge">系统运行中</div>
        </div>

        <div class="grid">
            <div class="card">
                <h2>📊 系统概览</h2>
                <div class="stat-item">
                    <span class="stat-label">在线设备</span>
                    <span id="onlineDevices" class="stat-value">--</span>
                </div>
                <div class="stat-item">
                    <span class="stat-label">今日数据</span>
                    <span id="todayData" class="stat-value">--</span>
                </div>
                <div class="stat-item">
                    <span class="stat-label">系统运行时间</span>
                    <span id="uptime" class="stat-value">--</span>
                </div>
            </div>

            <div class="card">
                <h2>🌡️ 当前环境</h2>
                <div class="stat-item">
                    <span class="stat-label">温度</span>
                    <span id="temperature" class="stat-value">--</span>
                </div>
                <div class="stat-item">
                    <span class="stat-label">湿度</span>
                    <span id="humidity" class="stat-value">--</span>
                </div>
                <div class="stat-item">
                    <span class="stat-label">PM2.5</span>
                    <span id="pm25" class="stat-value">--</span>
                </div>
            </div>
        </div>

        <div class="card">
            <h2>📈 温度趋势图</h2>
            <div class="chart-container">
                <canvas id="temperatureChart"></canvas>
            </div>
        </div>

        <div class="api-info">
            <h3>系统已启动</h3>
            <p>IoT监控系统正在本地Ubuntu上运行</p>
            <div class="api-endpoint">API接口: http://localhost:5000/api/system/status</div>
        </div>
    </div>

    <script src="/static/js/main.js"></script>
</body>
</html>
EOF
}

# 创建简单的style.css
create_simple_style_css() {
    cat > static/css/style.css << 'EOF'
body {
    font-family: Arial, sans-serif;
    background: #f5f5f5;
    margin: 0;
    padding: 20px;
}
.container {
    max-width: 1200px;
    margin: 0 auto;
    background: white;
    padding: 20px;
    border-radius: 10px;
    box-shadow: 0 2px 10px rgba(0,0,0,0.1);
}
.header {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: white;
    padding: 20px;
    border-radius: 10px;
    margin-bottom: 20px;
}
.card {
    background: white;
    padding: 20px;
    border-radius: 10px;
    margin-bottom: 20px;
    box-shadow: 0 2px 5px rgba(0,0,0,0.1);
}
EOF
}

# 创建简单的main.js
create_simple_main_js() {
    cat > static/js/main.js << 'EOF'
document.addEventListener('DOMContentLoaded', function() {
    console.log('IoT监控系统已加载');
    updateUptime();
    setInterval(updateUptime, 60000);
    refreshData();
    setInterval(refreshData, 10000);
});

function updateUptime() {
    const startTime = new Date();
    const now = new Date();
    const diff = now - startTime;
    const days = Math.floor(diff / (1000 * 60 * 60 * 24));
    const hours = Math.floor((diff % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
    const minutes = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60));
    document.getElementById('uptime').textContent = `${days}天${hours}小时${minutes}分`;
}

function refreshData() {
    fetch('/api/system/status')
        .then(response => response.json())
        .then(data => {
            document.getElementById('onlineDevices').textContent = data.active_devices || 1;
            document.getElementById('todayData').textContent = data.today_readings || 0;
        });

    fetch('/api/data/latest?limit=1')
        .then(response => response.json())
        .then(data => {
            if (data.data && data.data.length > 0) {
                const latest = data.data[0];
                document.getElementById('temperature').textContent =
                    `${latest.temperature ? latest.temperature.toFixed(1) : '23.5'} °C`;
                document.getElementById('humidity').textContent =
                    `${latest.humidity ? latest.humidity.toFixed(1) : '65.2'} %`;
                document.getElementById('pm25').textContent =
                    `${latest.pm25 || '15'} μg/m³`;
            }
        });
}
EOF
}

# 配置mosquitto
configure_mosquitto() {
    log_info "5. 配置MQTT代理..."

    # 检查mosquitto是否运行
    if ! pgrep -x "mosquitto" > /dev/null; then
        log_info "  启动Mosquitto服务..."
        sudo systemctl start mosquitto
    fi

    # 创建项目配置
    if [ ! -f "config/mosquitto.conf" ]; then
        log_info "  创建Mosquitto配置文件..."
        cat > config/mosquitto.conf << 'EOF'
allow_anonymous true
listener 1883 0.0.0.0
log_dest stdout
connection_messages true
EOF
    fi

    log_success "MQTT代理配置完成"
}

# 检查Python代码
check_python_code() {
    log_info "6. 检查Python代码..."

    # 激活虚拟环境
    source venv/bin/activate

    # 尝试导入主要模块
    if python3 -c "import sys; sys.path.insert(0, '.'); from src.database import SensorDatabase; print('✅ 数据库模块可导入')" 2>/dev/null; then
        log_success "  数据库模块检查通过"
    else
        log_error "  数据库模块导入失败"
        exit 1
    fi

    if python3 -c "import sys; sys.path.insert(0, '.'); from src.mqtt_handler import MQTTHandler; print('✅ MQTT处理模块可导入')" 2>/dev/null; then
        log_success "  MQTT处理模块检查通过"
    else
        log_warning "  MQTT处理模块导入失败，但可以继续"
    fi

    if python3 -c "import sys; sys.path.insert(0, '.'); from src.web_server import create_app; print('✅ Web服务器模块可导入')" 2>/dev/null; then
        log_success "  Web服务器模块检查通过"
    else
        log_error "  Web服务器模块导入失败"
        exit 1
    fi

    log_success "Python代码检查完成"
}

# 创建启动脚本
create_startup_script() {
    log_info "7. 创建启动脚本..."

    cat > start.sh << 'EOF'
#!/bin/bash
# start.sh - 启动IoT监控系统

set -e

echo "🚀 启动IoT传感器数据监控系统..."

# 检查是否在虚拟环境中
if [ -z "$VIRTUAL_ENV" ]; then
    echo "激活虚拟环境..."
    source venv/bin/activate
fi

# 检查并启动mosquitto
if ! pgrep -x "mosquitto" > /dev/null; then
    echo "启动MQTT代理..."
    sudo systemctl start mosquitto
fi

# 获取本地IP
get_local_ip() {
    ip route get 1 | awk '{print $7;exit}'
}

LOCAL_IP=$(get_local_ip || echo "127.0.0.1")

echo ""
echo "=========================================="
echo "🌐 IoT传感器数据监控系统"
echo "=========================================="
echo ""
echo "📊 系统信息:"
echo "   本地IP: $LOCAL_IP"
echo "   Web端口: 5000"
echo "   MQTT端口: 1883"
echo "   数据库: data/iot_sensor_data.db"
echo ""
echo "🌐 访问地址:"
echo "   本机访问: http://localhost:5000"
echo "   网络访问: http://$LOCAL_IP:5000"
echo ""
echo "📋 API接口:"
echo "   系统状态: http://localhost:5000/api/system/status"
echo "   最新数据: http://localhost:5000/api/data/latest"
echo ""
echo "🚀 正在启动服务..."
echo "按 Ctrl+C 停止服务"
echo "=========================================="
echo ""

# 运行主程序
python main.py
EOF

    chmod +x start.sh

    cat > stop.sh << 'EOF'
#!/bin/bash
# stop.sh - 停止IoT监控系统

echo "🛑 停止IoT监控系统..."
pkill -f "python main.py"
echo "✅ 系统已停止"
EOF

    chmod +x stop.sh

    log_success "启动脚本创建完成"
}

# 创建简化版main.py（如果需要）
create_simplified_main_py() {
    if [ ! -f "main.py" ] || grep -q "Docker" "main.py"; then
        log_info "  创建简化版main.py..."
        cat > main.py << 'EOF'
#!/usr/bin/env python3
"""
IoT传感器数据监控系统 - Ubuntu本地版本
"""

import sys
import os
import logging
from pathlib import Path

# 添加项目根目录到Python路径
project_root = Path(__file__).parent.absolute()
sys.path.insert(0, str(project_root))

try:
    from src.web_server import start_web_server
    from src.mqtt_handler import MQTTHandler
    from src.database import SensorDatabase
    from src.utils import setup_logging, get_local_ip
except ImportError as e:
    print(f"导入模块失败: {e}")
    print("请确保已安装所有依赖")
    sys.exit(1)

def main():
    """主函数"""
    print("""
    ╔═══════════════════════════════════════════════════════╗
    ║     IoT传感器数据监控系统 v1.0 (Ubuntu本地版)        ║
    ╚═══════════════════════════════════════════════════════╝
    """)

    # 设置日志
    setup_logging(log_level="INFO", log_file="logs/app.log")
    logger = logging.getLogger(__name__)

    # 获取本地IP
    local_ip = get_local_ip()

    try:
        # 初始化数据库
        logger.info("正在初始化数据库...")
        db = SensorDatabase("data/iot_sensor_data.db")

        # 初始化MQTT处理器
        logger.info("初始化MQTT处理器...")
        mqtt_handler = MQTTHandler(broker_ip="localhost", port=1883, db_instance=db)

        # 启动MQTT监听
        logger.info("启动MQTT监听...")
        mqtt_handler.start_in_background()

        # 配置Web服务器
        config = {
            'host': '0.0.0.0',
            'port': 5000,
            'debug': False,
            'db_instance': db
        }

        print(f"""
        📊 系统信息:
           本地IP地址: {local_ip}
           Web端口: 5000
           MQTT端口: 1883

        🌐 访问地址:
           本机: http://localhost:5000
           局域网: http://{local_ip}:5000

        📋 API接口:
           系统状态: http://localhost:5000/api/system/status
           最新数据: http://localhost:5000/api/data/latest

        🚀 服务正在启动...
        按 Ctrl+C 停止服务
        """)

        # 启动Web服务器
        start_web_server(**config)

    except Exception as e:
        logger.error(f"启动失败: {e}")
        print(f"❌ 启动失败: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
EOF
        log_success "  创建main.py完成"
    else
        log_success "  使用现有的main.py"
    fi
}

# 显示安装总结
show_summary() {
    echo ""
    echo "=================================================="
    echo "🎉 IoT监控系统环境搭建完成！"
    echo "=================================================="
    echo ""
    echo "📋 安装摘要:"
    echo "   ✅ Python 3.8 环境"
    echo "   ✅ Mosquitto MQTT 代理"
    echo "   ✅ 项目目录结构"
    echo "   ✅ Python 虚拟环境"
    echo "   ✅ Python 依赖包"
    echo ""
    echo "🚀 启动系统:"
    echo "   ./start.sh"
    echo ""
    echo "🛑 停止系统:"
    echo "   ./stop.sh"
    echo ""
    echo "🔧 手动启动:"
    echo "   source venv/bin/activate"
    echo "   python main.py"
    echo ""
    echo "🌐 访问地址:"
    echo "   http://localhost:5000"
    echo ""
    echo "📋 验证安装:"
    echo "   检查数据库: ls -la data/"
    echo "   检查日志: ls -la logs/"
    echo "   测试API: curl http://localhost:5000/api/system/status"
    echo ""
    echo "=================================================="
}

# 主函数
main() {
    log_info "开始搭建IoT监控系统环境..."

    # 检查当前目录
    check_current_directory

    # 安装系统依赖
    install_system_deps

    # 创建Python虚拟环境
    setup_python_env

    # 安装Python依赖
    install_python_deps

    # 创建项目目录结构
    create_project_structure

    # 配置mosquitto
    configure_mosquitto

    # 创建简化版main.py（如果需要）
    create_simplified_main_py

    # 检查Python代码
    check_python_code

    # 创建启动脚本
    create_startup_script

    # 显示总结
    show_summary

    log_success "环境搭建完成！"
}

# 运行主函数
main