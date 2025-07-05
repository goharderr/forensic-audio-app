#!/bin/bash

# Forensic Audio Processing - Vast.ai Deployment Script
# This script sets up the complete Docker environment on Vast.ai

set -e

echo "🚀 Starting Forensic Audio Processing deployment on Vast.ai..."

# Create project directory
mkdir -p /workspace/forensic-audio
cd /workspace/forensic-audio

# Create all necessary files
echo "📁 Creating project files..."

# Create requirements.txt
cat > requirements.txt << 'EOF'
fastapi==0.104.1
uvicorn[standard]==0.24.0
python-multipart==0.0.6
aiofiles==23.2.1
EOF

# Create Dockerfile
cat > Dockerfile << 'EOF'
# Dockerfile for Forensic Audio Processing
FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    ffmpeg \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements first (for better caching)
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY audio_server.py .

# Create temp directory
RUN mkdir -p /tmp/audio_processing

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Run the application
CMD ["python", "audio_server.py"]
EOF

# Create docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  forensic-audio:
    build: .
    ports:
      - "8000:8000"
    environment:
      - HOST=0.0.0.0
      - PORT=8000
    volumes:
      - ./temp:/tmp/audio_processing
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s
EOF

# Create the main application file
cat > audio_server.py << 'EOF'
#!/usr/bin/env python3
"""
Advanced Forensic Audio Processing Server
Optimized for Vast.ai deployment with real ffmpeg processing
"""

import os
import tempfile
import subprocess
import asyncio
import json
import logging
import shutil
from pathlib import Path
from datetime import datetime
from typing import Optional, Dict, Any

from fastapi import FastAPI, UploadFile, File, Form, HTTPException, Request
from fastapi.responses import FileResponse, HTMLResponse
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
import uvicorn

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="Forensic Audio Processing Server", version="2.0")

# Enable CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Create temp directory for processing
TEMP_DIR = Path("/tmp/audio_processing")
TEMP_DIR.mkdir(exist_ok=True)

# Forensic audio presets
PRESETS = {
    "whisper": {
        "name": "Whisper Mode",
        "description": "Optimized for whispers, quiet speech (30-3500 Hz)",
        "highpass": 30,
        "lowpass": 3500,
        "noise_reduction": 0.7,
        "dynamic_boost": 15,
        "voice_emphasis": 8,
        "eq_bands": [
            {"freq": 100, "gain": -6},   # Reduce low rumble
            {"freq": 300, "gain": 3},    # Boost voice fundamentals
            {"freq": 1000, "gain": 6},   # Boost voice clarity
            {"freq": 2000, "gain": 4},   # Boost voice harmonics
            {"freq": 3000, "gain": 2},   # Subtle high boost
        ]
    },
    "breath": {
        "name": "Breath Detection",
        "description": "Optimized for breathing, sighs (100-2000 Hz)",
        "highpass": 100,
        "lowpass": 2000,
        "noise_reduction": 0.4,
        "dynamic_boost": 25,
        "voice_emphasis": 3,
        "eq_bands": [
            {"freq": 200, "gain": 4},    # Boost breath frequencies
            {"freq": 500, "gain": 6},    # Boost breath harmonics
            {"freq": 1000, "gain": 3},   # Subtle mid boost
            {"freq": 1500, "gain": 2},   # High breath sounds
        ]
    },
    "vocal": {
        "name": "Vocal Isolation",
        "description": "Optimized for moans, grunts, vocal sounds (80-8000 Hz)",
        "highpass": 80,
        "lowpass": 8000,
        "noise_reduction": 0.6,
        "dynamic_boost": 12,
        "voice_emphasis": 10,
        "eq_bands": [
            {"freq": 150, "gain": 2},    # Boost vocal fundamentals
            {"freq": 400, "gain": 5},    # Boost vocal clarity
            {"freq": 1000, "gain": 8},   # Major vocal boost
            {"freq": 2000, "gain": 6},   # Vocal harmonics
            {"freq": 4000, "gain": 3},   # High vocal content
        ]
    },
    "tv_suppress": {
        "name": "TV Suppression",
        "description": "Aggressive TV background suppression (200-4000 Hz)",
        "highpass": 200,
        "lowpass": 4000,
        "noise_reduction": 0.9,
        "dynamic_boost": 20,
        "voice_emphasis": 12,
        "eq_bands": [
            {"freq": 60, "gain": -15},   # Kill TV low end
            {"freq": 120, "gain": -10},  # Kill TV harmonics
            {"freq": 500, "gain": 8},    # Boost voice over TV
            {"freq": 1500, "gain": 10},  # Strong voice boost
            {"freq": 3000, "gain": 6},   # High voice content
        ]
    },
    "extreme_whisper": {
        "name": "Extreme Whisper",
        "description": "Maximum enhancement for barely audible whispers",
        "highpass": 50,
        "lowpass": 4000,
        "noise_reduction": 0.85,
        "dynamic_boost": 30,
        "voice_emphasis": 15,
        "eq_bands": [
            {"freq": 80, "gain": -8},    # Reduce low rumble
            {"freq": 250, "gain": 8},    # Boost whisper fundamentals
            {"freq": 500, "gain": 12},   # Major whisper boost
            {"freq": 1000, "gain": 15},  # Maximum clarity boost
            {"freq": 2000, "gain": 10},  # Whisper harmonics
            {"freq": 3000, "gain": 6},   # High whisper content
        ]
    }
}

def build_ffmpeg_filter(preset_name: str, custom_params: Optional[Dict] = None) -> str:
    """Build advanced ffmpeg filter chain for forensic audio processing"""
    
    if preset_name not in PRESETS:
        raise ValueError(f"Unknown preset: {preset_name}")
    
    preset = PRESETS[preset_name].copy()
    
    # Override with custom parameters if provided
    if custom_params:
        preset.update(custom_params)
    
    filters = []
    
    # 1. High-pass filter (remove low-frequency noise)
    if preset["highpass"] > 0:
        filters.append(f"highpass=f={preset['highpass']}")
    
    # 2. Low-pass filter (remove high-frequency noise)
    if preset["lowpass"] > 0:
        filters.append(f"lowpass=f={preset['lowpass']}")
    
    # 3. Noise reduction using afftdn (FFT denoiser)
    if preset["noise_reduction"] > 0:
        nr_strength = preset["noise_reduction"]
        filters.append(f"afftdn=nr={nr_strength}:nf=-25")
    
    # 4. Dynamic range compressor (bring up quiet sounds)
    if preset["dynamic_boost"] > 0:
        ratio = 4 + (preset["dynamic_boost"] / 5)  # 4:1 to 10:1 ratio
        threshold = -30 + (preset["dynamic_boost"] / 2)  # Adaptive threshold
        filters.append(f"acompressor=threshold={threshold}dB:ratio={ratio}:attack=5:release=50")
    
    # 5. Equalizer (boost voice frequencies)
    if preset["eq_bands"]:
        for band in preset["eq_bands"]:
            filters.append(f"equalizer=f={band['freq']}:t=o:g={band['gain']}")
    
    # 6. Voice emphasis (mid-frequency boost)
    if preset["voice_emphasis"] > 0:
        voice_freq = 1000  # Center frequency for voice
        voice_gain = preset["voice_emphasis"]
        filters.append(f"equalizer=f={voice_freq}:t=o:g={voice_gain}:w=500")
    
    # 7. Final limiter (prevent clipping)
    filters.append("alimiter=level_in=1:level_out=0.9:limit=0.9")
    
    # 8. Volume normalization
    filters.append("loudnorm=I=-16:LRA=11:TP=-1.5")
    
    return ",".join(filters)

async def process_audio_file(
    input_path: Path,
    output_path: Path,
    preset_name: str = "whisper",
    custom_params: Optional[Dict] = None
) -> Dict[str, Any]:
    """Process audio file with advanced forensic filtering"""
    
    start_time = datetime.now()
    
    try:
        # Get input file info
        info_cmd = [
            "ffprobe", "-v", "quiet", "-print_format", "json",
            "-show_format", "-show_streams", str(input_path)
        ]
        
        result = subprocess.run(info_cmd, capture_output=True, text=True)
        if result.returncode != 0:
            raise Exception(f"Failed to analyze input file: {result.stderr}")
        
        file_info = json.loads(result.stdout)
        duration = float(file_info["format"]["duration"])
        
        # Build filter chain
        filter_chain = build_ffmpeg_filter(preset_name, custom_params)
        
        # Process audio with ffmpeg
        cmd = [
            "ffmpeg", "-y", "-i", str(input_path),
            "-af", filter_chain,
            "-c:a", "pcm_s16le",  # 16-bit PCM for compatibility
            "-ar", "44100",       # Standard sample rate
            "-ac", "2",           # Stereo output
            str(output_path)
        ]
        
        logger.info(f"Processing with command: {' '.join(cmd)}")
        
        # Run ffmpeg
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode != 0:
            raise Exception(f"FFmpeg processing failed: {result.stderr}")
        
        processing_time = (datetime.now() - start_time).total_seconds()
        
        # Get output file info
        output_size = output_path.stat().st_size
        
        return {
            "success": True,
            "input_duration": duration,
            "processing_time": processing_time,
            "output_size": output_size,
            "preset_used": preset_name,
            "filter_chain": filter_chain
        }
        
    except Exception as e:
        logger.error(f"Audio processing failed: {str(e)}")
        return {
            "success": False,
            "error": str(e)
        }

@app.get("/", response_class=HTMLResponse)
async def get_interface():
    """Serve the web interface"""
    return """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Forensic Audio Processing</title>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
            body {
                font-family: Arial, sans-serif;
                background: linear-gradient(135deg, #1e3c72 0%, #2a5298 100%);
                color: white;
                margin: 0;
                padding: 20px;
                min-height: 100vh;
            }
            .container {
                max-width: 1000px;
                margin: 0 auto;
                background: rgba(255,255,255,0.1);
                padding: 30px;
                border-radius: 15px;
                backdrop-filter: blur(10px);
            }
            h1 {
                text-align: center;
                margin-bottom: 30px;
                font-size: 2.5em;
                text-shadow: 0 2px 4px rgba(0,0,0,0.3);
            }
            .preset-buttons {
                display: flex;
                gap: 10px;
                margin-bottom: 30px;
                flex-wrap: wrap;
                justify-content: center;
            }
            .preset-btn {
                background: #ff6b6b;
                border: none;
                color: white;
                padding: 12px 20px;
                border-radius: 25px;
                cursor: pointer;
                font-weight: bold;
                transition: all 0.3s;
                font-size: 14px;
            }
            .preset-btn:hover {
                background: #ff5252;
                transform: translateY(-2px);
            }
            .preset-btn.active {
                background: #00d4ff;
                box-shadow: 0 4px 15px rgba(0,212,255,0.3);
            }
            .form-group {
                margin-bottom: 20px;
            }
            label {
                display: block;
                margin-bottom: 5px;
                font-weight: bold;
            }
            input[type="file"] {
                width: 100%;
                padding: 10px;
                border: 2px dashed #00d4ff;
                border-radius: 10px;
                background: rgba(255,255,255,0.1);
                color: white;
            }
            .process-button {
                background: linear-gradient(45deg, #00d4ff, #0099cc);
                border: none;
                color: white;
                padding: 15px 30px;
                border-radius: 25px;
                font-size: 1.1em;
                font-weight: bold;
                cursor: pointer;
                transition: all 0.3s;
                width: 100%;
            }
            .process-button:hover {
                transform: translateY(-2px);
                box-shadow: 0 6px 20px rgba(0,212,255,0.4);
            }
            .process-button:disabled {
                background: #666;
                cursor: not-allowed;
                transform: none;
            }
            .progress-container {
                margin-top: 20px;
                display: none;
            }
            .progress-bar {
                background: rgba(255,255,255,0.2);
                height: 25px;
                border-radius: 15px;
                overflow: hidden;
                margin-bottom: 10px;
            }
            .progress-fill {
                background: linear-gradient(45deg, #00d4ff, #0099cc);
                height: 100%;
                width: 0%;
                transition: width 0.3s;
                border-radius: 15px;
            }
            .status {
                text-align: center;
                font-weight: bold;
                color: #00d4ff;
            }
            .result {
                margin-top: 30px;
                padding: 20px;
                background: rgba(255,255,255,0.1);
                border-radius: 15px;
                display: none;
            }
            .audio-controls {
                margin-top: 20px;
            }
            audio {
                width: 100%;
                margin-bottom: 15px;
            }
            .download-btn {
                background: linear-gradient(45deg, #4CAF50, #45a049);
                text-decoration: none;
                color: white;
                padding: 12px 25px;
                border-radius: 25px;
                font-weight: bold;
                display: inline-block;
                transition: all 0.3s;
            }
            .download-btn:hover {
                transform: translateY(-2px);
                box-shadow: 0 4px 15px rgba(76,175,80,0.4);
            }
            .preset-info {
                background: rgba(255,255,255,0.1);
                padding: 15px;
                border-radius: 10px;
                margin-bottom: 20px;
                border-left: 4px solid #00d4ff;
            }
            .volume-control {
                margin-bottom: 15px;
            }
            .volume-control input {
                width: 100%;
                margin-top: 5px;
            }
            .file-info {
                background: rgba(255,255,255,0.05);
                padding: 10px;
                border-radius: 8px;
                margin-top: 10px;
                font-size: 14px;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🔍 Forensic Audio Processing</h1>
            
            <div class="preset-buttons">
                <button class="preset-btn active" onclick="selectPreset('whisper')">👤 Whisper Mode</button>
                <button class="preset-btn" onclick="selectPreset('breath')">💨 Breath Detection</button>
                <button class="preset-btn" onclick="selectPreset('vocal')">🎵 Vocal Isolation</button>
                <button class="preset-btn" onclick="selectPreset('tv_suppress')">📺 TV Suppression</button>
                <button class="preset-btn" onclick="selectPreset('extreme_whisper')">🔥 Extreme Whisper</button>
            </div>
            
            <div class="preset-info" id="preset-info">
                <strong>👤 Whisper Mode:</strong> Optimized for whispers, quiet speech (30-3500 Hz)
            </div>
            
            <div class="form-group">
                <label>📁 Select Audio File (MP3, WAV, MP4):</label>
                <input type="file" id="audioFile" accept="audio/*,video/*" onchange="fileSelected()">
                <div class="file-info" id="file-info" style="display: none;"></div>
            </div>
            
            <button class="process-button" id="processBtn" onclick="processAudio()" disabled>
                🔄 Process Audio
            </button>
            
            <div class="progress-container" id="progressContainer">
                <div class="progress-bar">
                    <div class="progress-fill" id="progressFill"></div>
                </div>
                <div class="status" id="statusText">Ready</div>
            </div>
            
            <div class="result" id="result">
                <h3>✅ Processing Complete!</h3>
                <div class="audio-controls">
                    <div class="volume-control">
                        <label>🔊 Volume: <span id="volume-display">100%</span></label>
                        <input type="range" id="volumeSlider" min="0" max="200" value="100" onchange="updateVolume()">
                    </div>
                    <audio id="audioPlayer" controls></audio>
                    <a href="#" class="download-btn" id="downloadBtn">💾 Download Processed Audio</a>
                </div>
                <div id="processingInfo" style="margin-top: 15px; font-size: 14px; opacity: 0.8;"></div>
            </div>
        </div>
        
        <script>
            let selectedPreset = 'whisper';
            let processing = false;
            
            const presets = {
                'whisper': {
                    name: '👤 Whisper Mode',
                    description: 'Optimized for whispers, quiet speech (30-3500 Hz)'
                },
                'breath': {
                    name: '💨 Breath Detection',
                    description: 'Optimized for breathing, sighs (100-2000 Hz)'
                },
                'vocal': {
                    name: '🎵 Vocal Isolation',
                    description: 'Optimized for moans, grunts, vocal sounds (80-8000 Hz)'
                },
                'tv_suppress': {
                    name: '📺 TV Suppression',
                    description: 'Aggressive TV background suppression (200-4000 Hz)'
                },
                'extreme_whisper': {
                    name: '🔥 Extreme Whisper',
                    description: 'Maximum enhancement for barely audible whispers'
                }
            };
            
            function selectPreset(preset) {
                selectedPreset = preset;
                document.querySelectorAll('.preset-btn').forEach(btn => btn.classList.remove('active'));
                event.target.classList.add('active');
                
                const info = presets[preset];
                document.getElementById('preset-info').innerHTML = 
                    `<strong>${info.name}:</strong> ${info.description}`;
            }
            
            function fileSelected() {
                const file = document.getElementById('audioFile').files[0];
                const fileInfo = document.getElementById('file-info');
                
                if (file) {
                    const size = (file.size / 1024 / 1024).toFixed(2);
                    fileInfo.innerHTML = `
                        <strong>📄 File:</strong> ${file.name}<br>
                        <strong>📊 Size:</strong> ${size} MB<br>
                        <strong>🎵 Type:</strong> ${file.type}
                    `;
                    fileInfo.style.display = 'block';
                    document.getElementById('processBtn').disabled = false;
                } else {
                    fileInfo.style.display = 'none';
                    document.getElementById('processBtn').disabled = true;
                }
            }
            
            function updateVolume() {
                const volume = document.getElementById('volumeSlider').value;
                const audio = document.getElementById('audioPlayer');
                audio.volume = volume / 100;
                document.getElementById('volume-display').textContent = volume + '%';
            }
            
            async function processAudio() {
                if (processing) return;
                
                const fileInput = document.getElementById('audioFile');
                const file = fileInput.files[0];
                
                if (!file) {
                    alert('Please select an audio file');
                    return;
                }
                
                processing = true;
                document.getElementById('processBtn').disabled = true;
                document.getElementById('progressContainer').style.display = 'block';
                document.getElementById('result').style.display = 'none';
                
                // Show progress
                updateProgress(10, 'Uploading file...');
                
                const formData = new FormData();
                formData.append('file', file);
                formData.append('preset', selectedPreset);
                
                try {
                    updateProgress(20, 'Processing audio...');
                    
                    const response = await fetch('/process', {
                        method: 'POST',
                        body: formData
                    });
                    
                    if (!response.ok) {
                        throw new Error(`HTTP error! status: ${response.status}`);
                    }
                    
                    updateProgress(90, 'Finalizing...');
                    
                    const blob = await response.blob();
                    const url = URL.createObjectURL(blob);
                    
                    // Set up audio player
                    const audioPlayer = document.getElementById('audioPlayer');
                    audioPlayer.src = url;
                    audioPlayer.volume = 1.0;
                    
                    // Set up download
                    const downloadBtn = document.getElementById('downloadBtn');
                    downloadBtn.href = url;
                    downloadBtn.download = `processed_${file.name}`;
                    
                    // Show result
                    document.getElementById('result').style.display = 'block';
                    updateProgress(100, 'Complete!');
                    
                    // Show processing info
                    document.getElementById('processingInfo').innerHTML = 
                        `<strong>🎚️ Preset:</strong> ${presets[selectedPreset].name}<br>
                         <strong>📁 Output:</strong> 44.1kHz 16-bit WAV`;
                    
                } catch (error) {
                    console.error('Error:', error);
                    alert('Error processing audio: ' + error.message);
                    updateProgress(0, 'Error occurred');
                } finally {
                    processing = false;
                    document.getElementById('processBtn').disabled = false;
                }
            }
            
            function updateProgress(percent, message) {
                document.getElementById('progressFill').style.width = percent + '%';
                document.getElementById('statusText').textContent = message;
            }
        </script>
    </body>
    </html>
    """

@app.post("/process")
async def process_audio(
    file: UploadFile = File(...),
    preset: str = Form("whisper")
):
    """Process uploaded audio file"""
    
    # Create unique temp files
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    input_path = TEMP_DIR / f"input_{timestamp}_{file.filename}"
    output_path = TEMP_DIR / f"output_{timestamp}.wav"
    
    try:
        # Save uploaded file
        with open(input_path, "wb") as f:
            content = await file.read()
            f.write(content)
        
        logger.info(f"Processing {file.filename} with preset '{preset}'")
        
        # Process audio
        result = await process_audio_file(
            input_path, output_path, preset
        )
        
        if not result["success"]:
            raise HTTPException(status_code=500, detail=result["error"])
        
        # Return processed file
        return FileResponse(
            path=output_path,
            media_type="audio/wav",
            filename=f"processed_{file.filename}"
        )
        
    except Exception as e:
        logger.error(f"Processing failed: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))
    
    finally:
        # Cleanup temp files
        for temp_file in [input_path, output_path]:
            if temp_file.exists():
                try:
                    temp_file.unlink()
                except:
                    pass

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "presets": list(PRESETS.keys()),
        "temp_dir": str(TEMP_DIR)
    }

if __name__ == "__main__":
    # For deployment
    port = int(os.environ.get("PORT", 8000))
    host = os.environ.get("HOST", "0.0.0.0")
    
    print(f"🚀 Starting Forensic Audio Processing Server on {host}:{port}")
    print(f"📁 Temp directory: {TEMP_DIR}")
    print(f"🎚️ Available presets: {list(PRESETS.keys())}")
    
    uvicorn.run(app, host=host, port=port)
EOF

# Create temp directory for processing
mkdir -p temp

echo "🐳 Building Docker image..."
docker build -t forensic-audio .

echo "🚀 Starting the application..."
docker-compose up -d

echo "✅ Deployment complete!"
echo ""
echo "🌐 Access your application at:"
echo "   http://localhost:8000"
echo ""
echo "📋 Available commands:"
echo "   docker-compose logs -f    # View logs"
echo "   docker-compose down       # Stop application"
echo "   docker-compose up -d      # Start application"
echo ""
echo "🎯 For Vast.ai external access, use:"
echo "   http://YOUR_VAST_IP:8000"
echo ""
echo "🔧 Presets available:"
echo "   👤 Whisper Mode - For quiet speech & whispers"
echo "   💨 Breath Detection - For breathing & sighs"
echo "   🎵 Vocal Isolation - For moans & vocal sounds"
echo "   📺 TV Suppression - Aggressive background TV removal"
echo "   🔥 Extreme Whisper - Maximum enhancement for barely audible sounds"