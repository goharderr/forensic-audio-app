# 🔍 Forensic Audio Processing

Advanced audio processing tool specifically designed for forensic analysis and enhancement of quiet human vocalizations (whispers, breathing, moans, grunts) in noisy environments.

![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)
![Python](https://img.shields.io/badge/python-3670A0?style=for-the-badge&logo=python&logoColor=ffdd54)
![FastAPI](https://img.shields.io/badge/FastAPI-005571?style=for-the-badge&logo=fastapi)

## 🎯 Features

- **Specialized Presets**: Clean Whisper, TV Suppression, Breath Detection, Vocal Isolation
- **Minimal Artifacts**: Optimized to reduce white noise and processing artifacts
- **Real FFmpeg Processing**: Professional-grade audio enhancement
- **Docker Ready**: Easy deployment on Vast.ai, AWS, or local machines
- **Web Interface**: Simple, intuitive browser-based interface
- **Large File Support**: Handles 10+ minute audio files efficiently (tested with 55MB files)
- **Volume Boost**: Up to 200% volume amplification for quiet sounds

## 🚀 Quick Start

### One-Command Deployment (Vast.ai)
```bash
curl -sSL https://raw.githubusercontent.com/goharderr/forensic-audio-app/main/deploy_vast.sh | bash
```

### Local Docker Setup
```bash
git clone https://github.com/goharderr/forensic-audio-app.git
cd forensic-audio-app
docker-compose up -d
```

Access at: `http://localhost:8000`

## 🎚️ Audio Processing Presets

### ✨ Clean Whisper (Recommended)
- **Best for**: Quiet speech, whispers with minimal artifacts
- **Processing**: Very gentle enhancement
- **Perfect for**: Initial testing and clean audio

### 🔧 Gentle Enhancement
- **Best for**: Slight audio improvement without artifacts
- **Processing**: Minimal noise reduction and EQ
- **Perfect for**: Subtle enhancement

### 👤 Whisper Mode
- **Best for**: Standard whisper enhancement
- **Frequency**: 30-3500 Hz
- **Processing**: Moderate enhancement

### 📺 TV Suppression
- **Best for**: Audio with TV background noise
- **Processing**: Targets TV frequencies while preserving voice
- **Perfect for**: Forensic scenarios with background TV

### 💨 Breath Detection
- **Best for**: Breathing, sighs, respiratory sounds
- **Frequency**: 100-2000 Hz
- **Processing**: Optimized for breath frequency range

### 🎵 Vocal Isolation
- **Best for**: Moans, grunts, vocal sounds
- **Frequency**: 80-8000 Hz
- **Processing**: Balanced vocal enhancement

## 📊 Performance

- **Small files** (< 10MB): < 30 seconds
- **Medium files** (10-50MB): 30-60 seconds  
- **Large files** (50MB+): 1-3 minutes
- **Memory usage**: ~500MB-1GB depending on file size
- **Tested with**: 55MB, 10-minute audio files

## 🔧 System Requirements

- **Docker & Docker Compose**
- **2GB+ RAM** (4GB recommended for large files)
- **1GB+ storage space**
- **Modern browser** (Chrome, Firefox, Safari, Edge)

## 🏗️ Architecture

- **Backend**: FastAPI with Python 3.11
- **Audio Processing**: FFmpeg with custom filter chains
- **Frontend**: Modern HTML5 with JavaScript
- **Deployment**: Docker containers
- **Platform**: Cross-platform (Windows, Linux, macOS)

## 🛠️ Installation Methods

### Method 1: Docker (Recommended)
```bash
git clone https://github.com/goharderr/forensic-audio-app.git
cd forensic-audio-app
docker-compose up -d
```

### Method 2: Vast.ai Deployment
1. Rent a Vast.ai instance
2. Run the one-command deployment script
3. Access via your Vast.ai external IP

### Method 3: Local Development
```bash
pip install fastapi uvicorn python-multipart
python audio_server.py
```

## 🌐 API Usage

### Process Audio File
```bash
curl -X POST \
  -F "file=@input.wav" \
  -F "preset=clean_whisper" \
  http://localhost:8000/process \
  -o output.wav
```

### Available Endpoints
- `GET /` - Web interface
- `POST /process` - Process audio file
- `GET /health` - Health check
- `GET /debug` - Debug information

## 📖 Use Cases

### Forensic Analysis
- **Whisper detection** in recorded conversations
- **Background noise suppression** (TV, traffic, etc.)
- **Breathing pattern analysis**
- **Voice isolation** in multi-speaker recordings

### Audio Enhancement
- **Quiet conversation clarification**
- **Old recording restoration**
- **Interview audio cleanup**
- **Surveillance audio improvement**

## 🔒 Security & Legal

⚠️ **Important**: This tool is designed for legitimate forensic analysis and audio enhancement purposes. Users must:

- Have proper authorization before processing any audio content
- Comply with local laws regarding audio recording and analysis
- Respect privacy and consent requirements
- Use only for legal and ethical purposes

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Add tests if applicable
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Issues**: Use [GitHub Issues](https://github.com/goharderr/forensic-audio-app/issues) for bug reports
- **Discussions**: Use [GitHub Discussions](https://github.com/goharderr/forensic-audio-app/discussions) for questions
- **Wiki**: Check the [Wiki](https://github.com/goharderr/forensic-audio-app/wiki) for advanced usage

## 🔄 Changelog

### v2.0.0 (Latest)
- ✨ Added Clean Whisper and Gentle Enhancement presets
- 🐛 Fixed white noise and artifact issues
- 🔧 Optimized FFmpeg filter chains
- 📈 Improved processing performance
- 🛡️ Enhanced error handling

### v1.0.0
- 🎉 Initial release
- 🎚️ Basic preset system
- 🐳 Docker deployment support

## 🙏 Acknowledgments

- **FFmpeg community** for the excellent audio processing library
- **FastAPI team** for the robust web framework
- **Docker** for containerization technology
- **Vast.ai** for accessible GPU/CPU rental platform

## 📊 Project Stats

![GitHub stars](https://img.shields.io/github/stars/goharderr/forensic-audio-app?style=social)
![GitHub forks](https://img.shields.io/github/forks/goharderr/forensic-audio-app?style=social)
![GitHub issues](https://img.shields.io/github/issues/goharderr/forensic-audio-app)
![GitHub license](https://img.shields.io/github/license/goharderr/forensic-audio-app)

---

**Made with ❤️ for the forensic audio analysis community**