#!/bin/bash

# 激活conda
source /scratch/prj0000000262-bucket/ocr/ec/env/bin/activate.  
# conda activate timesearch

# 1. 先进入项目根目录
PROJECT_ROOT="/scratch/prj0000000262-bucket/ocr/ec/TimeSearch-R_latest"
echo "尝试进入项目目录: $PROJECT_ROOT"

if [ -d "$PROJECT_ROOT" ]; then
    cd "$PROJECT_ROOT"
    echo "成功进入: $(pwd)"
else
    echo "错误：目录不存在，尝试其他路径..."
    cd ~/TimeSearch-R 2>/dev/null || cd /TimeSearch-R 2>/dev/null || cd .
fi

# echo "当前目录: $(pwd)"
# echo "目录内容:"
# ls -la

# 2. 后台启动 CLIP Server
echo ""
echo "==============================="
echo "后台启动 CLIP Server..."
echo "==============================="

if [ -d "clip_as_service/server/" ]; then
    echo "进入server目录..."
    cd clip_as_service/server
    
    if [ -f "start.sh" ]; then
        # 在后台启动 server，并重定向日志到文件
        nohup bash start.sh > clip_server.log 2>&1 &
        SERVER_PID=$!
        echo "CLIP Server 启动中 (PID: $SERVER_PID)"
        echo "日志输出到: $(pwd)/clip_server.log"
        
        # 等待server启动完成（检查日志中的成功消息）
        echo -n "等待 CLIP Server 启动"
        ATTEMPTS=0
        MAX_ATTEMPTS=15
        SERVER_READY=0
        
        while [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
            if tail -5 clip_server.log 2>/dev/null | grep -q "Flow is ready to serve"; then
                echo ""
                echo "✅ CLIP Server 启动成功！"
                SERVER_READY=1
                break
            fi
            echo -n "."
            sleep 2
            ATTEMPTS=$((ATTEMPTS + 1))
        done
        
        if [ $SERVER_READY -eq 0 ]; then
            echo ""
            echo "⚠️  CLIP Server 启动可能较慢，继续检查..."
            # 再等10秒
            sleep 3600
        fi
        
        # 显示最后几行日志
        echo ""
        echo "CLIP Server 日志最后10行:"
        tail -10 clip_server.log
        
        echo ""
        echo "CLIP Server 进程状态:"
        ps -p $SERVER_PID >/dev/null 2>&1 && echo "✅ 进程运行中 (PID: $SERVER_PID)" || echo "❌ 进程已停止"
        
    else
        echo "错误：start.sh 不存在"
    fi
    
    # 返回到项目根目录
    cd ../..
else
    echo "跳过server启动，目录不存在"
fi

# 3. 运行训练脚本
echo ""
echo "==============================="
echo "启动训练脚本..."
echo "==============================="


    
# 在子shell中运行训练脚本，保持前台可见
echo "开始训练..."
bash scripts/train_sft.sh
echo "成功找到..."
    


# 4. 清理函数（可选）
cleanup() {
    echo ""
    echo "正在清理..."
    if [ -n "$SERVER_PID" ]; then
        echo "停止 CLIP Server (PID: $SERVER_PID)"
        kill $SERVER_PID 2>/dev/null
    fi
    exit 0
}

# 捕获退出信号
trap cleanup SIGINT SIGTERM EXIT
