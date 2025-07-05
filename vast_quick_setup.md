# 🚀 Vast.ai Forensic Audio Processing - Quick Setup

## Method 1: One-Command Setup (Recommended)

```bash
curl -sSL https://raw.githubusercontent.com/YOUR_USERNAME/forensic-audio/main/deploy_vast.sh | bash
```

## Method 2: Manual Setup

### Step 1: Create Project Directory
```bash
mkdir -p /workspace/forensic-audio
cd /workspace/forensic-audio
```

### Step 2: Download Files
Download all the files from the artifacts above and save them in your project directory:
- `audio_server.py`
- `Dockerfile`
- `docker-compose.yml`
- `requirements.txt`
- `deploy_vast.sh`

### Step 3: Make Deploy Script Executable
```bash
chmod +x deploy_vast.sh
```

### Step 4: Run Deployment
```bash
./deploy_vast.sh
```

## Method 3: Docker-only Setup

```bash
# Build the image
docker build -t forensic-audio .

# Run the container
docker run -d \
  --name forensic-audio \
  -p 8000:8000 \
  -v $(pwd)/temp:/tmp/audio_processing \
  forensic-audio
```

## 🌐 Accessing Your Application

### Local Access (for testing)
```
http://localhost:8000
```

### Vast.ai External Access
```
http://YOUR_VAST_IP:8000
```

To find your Vast.ai external IP:
1. Check your Vast.ai dashboard
2. Look for "Connect" button next to your instance
3. Use the IP shown there

## 🔧 Port Configuration

If you need to use a different port:

```bash
# Edit docker-compose.yml
ports:
  - "YOUR_PORT:8000"

# Or run directly with Docker
docker run -d -p YOUR_PORT:8000 forensic-audio
```

## 🎯 Optimized Presets for Your Use Case

### 👤 Whisper Mode (Recommended for your scenario)
- **Best for**: Quiet speech, whispers over TV background
- **Frequency**: 30-3500 Hz
- **Noise Reduction**: 70% (aggressive TV suppression)
- **Dynamic Boost**: High compression for quiet sounds

### 📺 TV Suppression Mode
- **Best for**: When TV is very loud
- **Frequency**: 200-4000 Hz (cuts TV low-end)
- **Noise Reduction**: 90% (maximum suppression)
- **EQ**: -15dB at 60Hz (kills TV bass)

### 🔥 Extreme Whisper Mode
- **Best for**: Barely audible sounds
- **Maximum enhancement**: All settings at highest levels
- **Use when**: Other modes aren't enough

## 📊 File Size Recommendations

- **Small files** (< 10MB): All presets work fast
- **Medium files** (10-50MB): 30-60 seconds processing
- **Large files** (50MB+): 1-3 minutes processing

Your 55MB, 10-minute files will process in about 1-2 minutes.

## 🔍 Troubleshooting

### Container won't start
```bash
# Check logs
docker-compose logs -f

# Or
docker logs forensic-audio
```

### Port already in use
```bash
# Stop existing containers
docker-compose down

# Or kill process using port
sudo lsof -ti:8000 | xargs kill -9
```

### FFmpeg not found
The Docker image includes FFmpeg, but if you see this error:
```bash
# Install in container
docker exec forensic-audio apt-get update
docker exec forensic-audio apt-get install -y ffmpeg
```

### Out of memory
For very large files (100MB+):
```bash
# Increase Docker memory limit
docker run -d --memory=2g -p 8000:8000 forensic-audio
```

## 🔄 Updating the Application

```bash
# Stop current version
docker-compose down

# Rebuild with changes
docker-compose up -d --build
```

## 📋 Useful Commands

```bash
# View real-time logs
docker-compose logs -f

# Restart application
docker-compose restart

# Stop application
docker-compose down

# Check container status
docker-compose ps

# Access container shell
docker exec -it forensic-audio bash
```

## 💾 Persistent Storage

Your processed files are stored in `./temp/` directory, which persists between container restarts.

## 🔐 Security Notes

- The application runs on HTTP (not HTTPS)
- Files are temporarily stored and auto-deleted after processing
- No authentication required (suitable for private Vast.ai instances)

## 📞 Support

If you encounter issues:
1. Check the logs: `docker-compose logs -f`
2. Verify FFmpeg is working: `docker exec forensic-audio ffmpeg -version`
3. Test with a small file first
4. Check available disk space: `df -h`

## 🎯 Performance Tips

1. **Use Whisper Mode** for your TV background scenario
2. **Start with smaller files** to test settings
3. **Volume can go up to 200%** for very quiet sounds
4. **Download processed files** immediately after processing
5. **Try different presets** if results aren't optimal