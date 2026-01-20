#!/bin/bash
# solve-mosquitto.sh - 彻底解决mosquitto进程问题

echo ""
echo "🔧 彻底解决Mosquitto进程问题"
echo "============================"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检查当前系统
echo "🔍 检查系统状态..."

# 1. 查看所有mosquitto进程
echo ""
echo "1. 当前所有mosquitto进程:"
ps aux | grep -E "[m]osquitto|[m]osquitto.conf" || echo "  没有找到mosquitto进程"

# 2. 查看系统服务状态
echo ""
echo "2. 系统服务状态:"
if command -v systemctl >/dev/null 2>&1; then
    sudo systemctl status mosquitto --no-pager | head -20
elif command -v service >/dev/null 2>&1; then
    sudo service mosquitto status
else
    echo "  无法检查服务状态"
fi

# 3. 查看端口占用
echo ""
echo "3. 端口占用情况:"
sudo netstat -tlnp | grep :1883 || echo "  端口1883未被占用"

# 4. 查找mosquitto配置文件
echo ""
echo "4. Mosquitto配置文件:"
find /etc -name "*mosquitto*" -type f 2>/dev/null | head -10
find /usr -name "*mosquitto*" -type f 2>/dev/null | head -10

# 显示问题分析
echo ""
echo "📋 问题分析:"
echo "   您遇到的问题是系统服务自动重启了mosquitto进程。"
echo "   当您kill一个进程后，系统服务管理器（如systemd）会自动重启它。"
echo ""
echo "🎯 解决方案:"
echo "   1. 停止并禁用系统服务"
echo "   2. 清理所有现有进程"
echo "   3. 手动启动mosquitto"
echo "   4. 或者修改系统服务配置"

# 询问用户选择哪种方案
echo ""
echo "请选择解决方案:"
echo "1) 停止系统服务，手动启动mosquitto（推荐）"
echo "2) 修改系统服务配置，使用项目配置文件"
echo "3) 查看详细系统日志"
read -p "请输入选项 (1-3): " choice

case $choice in
    1)
        echo ""
        echo "🛑 停止并禁用系统服务..."
        sudo systemctl stop mosquitto 2>/dev/null
        sudo systemctl disable mosquitto 2>/dev/null
        
        echo "🔫 清理所有mosquitto进程..."
        sudo pkill -9 mosquitto 2>/dev/null
        sudo pkill -9 mosquitto.conf 2>/dev/null
        
        echo "⏳ 等待2秒..."
        sleep 2
        
        echo "🔍 验证清理结果:"
        if ps aux | grep -q "[m]osquitto"; then
            echo -e "${RED}✗ 仍有mosquitto进程运行${NC}"
            sudo pkill -9 mosquitto
        else
            echo -e "${GREEN}✓ 所有mosquitto进程已清理${NC}"
        fi
        
        echo ""
        echo "🚀 手动启动mosquitto..."
        if [ -f "config/mosquitto.conf" ]; then
            echo "使用项目配置文件: config/mosquitto.conf"
            # 在前台启动，以便查看输出
            echo "启动命令: mosquitto -c config/mosquitto.conf -v"
            echo ""
            echo "💡 提示: 保持这个终端窗口打开，新开一个终端运行IoT系统"
            echo "或者按 Ctrl+C 停止mosquitto，然后运行: nohup mosquitto -c config/mosquitto.conf > mosquitto.log 2>&1 &"
            echo ""
            read -p "是否在前台启动mosquitto？(y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                mosquitto -c config/mosquitto.conf -v
            else
                nohup mosquitto -c config/mosquitto.conf > mosquitto.log 2>&1 &
                echo "✅ Mosquitto已在后台启动，日志: mosquitto.log"
                echo "进程PID: $!"
            fi
        else
            echo -e "${RED}✗ 项目配置文件不存在: config/mosquitto.conf${NC}"
        fi
        ;;
        
    2)
        echo ""
        echo "⚙️  修改系统服务配置..."
        
        # 查找系统配置文件
        MOSQUITTO_CONF_SYSTEM=$(find /etc -name "mosquitto.conf" 2>/dev/null | head -1)
        if [ -z "$MOSQUITTO_CONF_SYSTEM" ]; then
            echo "未找到系统mosquitto配置文件"
        else
            echo "系统配置文件: $MOSQUITTO_CONF_SYSTEM"
            echo ""
            echo "当前配置:"
            echo "----------"
            head -20 "$MOSQUITTO_CONF_SYSTEM"
            echo "----------"
            
            read -p "是否备份并替换为项目配置？(y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                sudo cp "$MOSQUITTO_CONF_SYSTEM" "${MOSQUITTO_CONF_SYSTEM}.bak"
                sudo cp config/mosquitto.conf "$MOSQUITTO_CONF_SYSTEM"
                echo "✅ 配置文件已替换"
                
                echo "🔄 重启服务..."
                sudo systemctl restart mosquitto
                sleep 2
                sudo systemctl status mosquitto --no-pager | head -10
            fi
        fi
        ;;
        
    3)
        echo ""
        echo "📋 系统日志:"
        echo "=========="
        sudo journalctl -u mosquitto --no-pager -n 30 2>/dev/null || echo "无法获取日志"
        echo "=========="
        ;;
        
    *)
        echo "无效选项"
        ;;
esac

# 创建简易启动脚本
echo ""
echo "📝 创建简易启动脚本..."
cat > start-mosquitto.sh << 'EOF'
#!/bin/bash
# start-mosquitto.sh - 启动项目mosquitto

# 停止系统服务
sudo systemctl stop mosquitto 2>/dev/null

# 清理现有进程
sudo pkill -9 mosquitto 2>/dev/null

# 等待
sleep 2

# 启动项目mosquitto
if [ -f "config/mosquitto.conf" ]; then
    echo "启动项目mosquitto..."
    nohup mosquitto -c config/mosquitto.conf > mosquitto.log 2>&1 &
    echo "✅ Mosquitto已启动"
    echo "日志: mosquitto.log"
    echo "PID: $!"
else
    echo "❌ 配置文件不存在: config/mosquitto.conf"
fi
EOF

chmod +x start-mosquitto.sh

cat > stop-mosquitto.sh << 'EOF'
#!/bin/bash
# stop-mosquitto.sh - 停止项目mosquitto

echo "停止mosquitto..."
sudo pkill -9 mosquitto 2>/dev/null
echo "✅ 已停止"

# 可选：重新启动系统服务
# sudo systemctl start mosquitto
EOF

chmod +x stop-mosquitto.sh

echo ""
echo "✅ 已创建脚本:"
echo "   start-mosquitto.sh - 启动项目mosquitto"
echo "   stop-mosquitto.sh  - 停止项目mosquitto"
echo ""
echo "📋 使用步骤:"
echo "   1. ./start-mosquitto.sh"
echo "   2. source venv/bin/activate"
echo "   3. python main.py"
echo "   4. ./stop-mosquitto.sh (完成后)"
echo ""
echo "💡 提示: 系统服务已禁用，重启系统后会恢复"
