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

# Forensic audio presets - OPTIMIZED FOR MINIMAL WHITE NOISE
PRESETS = {
    "whisper": {
        "name": "Whisper Mode",
        "description": "Optimized for whispers, minimal white noise (30-3500 Hz)",
        "highpass": 30,
        "lowpass": 3500,
        "noise_reduction": 0.5,  # Reduced from 0.7 to minimize artifacts
        "dynamic_boost": 8,      # Reduced from 15 to prevent noise amplification
        "voice_emphasis": 4,     # Reduced from 8 to minimize artifacts
        "eq_bands": [
            {"freq": 100, "gain": -3},   # Gentler low-end reduction
            {"freq": 300, "gain": 2},    # Subtle voice fundamental boost
            {"freq": 1000, "gain": 3},   # Moderate voice clarity boost
            {"freq": 2000, "gain": 2},   # Gentle harmonic boost
        ]
    },
    "breath": {
        "name": "Breath Detection",
        "description": "Optimized for breathing, minimal processing (100-2000 Hz)",
        "highpass": 100,
        "lowpass": 2000,
        "noise_reduction": 0.3,  # Very gentle noise reduction
        "dynamic_boost": 12,     # Moderate compression
        "voice_emphasis": 2,     # Minimal emphasis
        "eq_bands": [
            {"freq": 200, "gain": 2},    # Gentle breath boost
            {"freq": 500, "gain": 3},    # Moderate breath harmonics
            {"freq": 1000, "gain": 2},   # Subtle mid boost
        ]
    },
    "vocal": {
        "name": "Vocal Isolation",
        "description": "Optimized for vocal sounds, balanced processing (80-8000 Hz)",
        "highpass": 80,
        "lowpass": 8000,
        "noise_reduction": 0.4,  # Moderate noise reduction
        "dynamic_boost": 6,      # Gentle compression
        "voice_emphasis": 5,     # Moderate emphasis
        "eq_bands": [
            {"freq": 150, "gain": 1},    # Gentle vocal fundamentals
            {"freq": 400, "gain": 3},    # Moderate vocal clarity
            {"freq": 1000, "gain": 4},   # Voice boost
            {"freq": 2000, "gain": 3},   # Vocal harmonics
        ]
    },
    "tv_suppress": {
        "name": "TV Suppression",
        "description": "TV background suppression, minimal artifacts (200-4000 Hz)",
        "highpass": 200,
        "lowpass": 4000,
        "noise_reduction": 0.6,  # Moderate but not excessive
        "dynamic_boost": 10,     # Balanced compression
        "voice_emphasis": 6,     # Moderate voice emphasis
        "eq_bands": [
            {"freq": 60, "gain": -8},    # Reduce TV low end (gentler)
            {"freq": 120, "gain": -5},   # Reduce TV harmonics (gentler)
            {"freq": 500, "gain": 4},    # Moderate voice boost
            {"freq": 1500, "gain": 5},   # Voice clarity
            {"freq": 3000, "gain": 3},   # High voice content
        ]
    },
    "clean_whisper": {
        "name": "Clean Whisper",
        "description": "Minimal processing for very clean whisper enhancement",
        "highpass": 50,
        "lowpass": 4000,
        "noise_reduction": 0.2,  # Very gentle noise reduction
        "dynamic_boost": 4,      # Minimal compression
        "voice_emphasis": 2,     # Subtle emphasis
        "eq_bands": [
            {"freq": 250, "gain": 2},    # Gentle whisper boost
            {"freq": 500, "gain": 3},    # Moderate whisper clarity
            {"freq": 1000, "gain": 2},   # Subtle clarity boost
        ]
    },
    "gentle_enhance": {
        "name": "Gentle Enhancement",
        "description": "Minimal processing for slight audio improvement",
        "highpass": 40,
        "lowpass": 6000,
        "noise_reduction": 0.1,  # Minimal noise reduction
        "dynamic_boost": 2,      # Very gentle compression
        "voice_emphasis": 1,     # Minimal emphasis
        "eq_bands": [
            {"freq": 300, "gain": 1},    # Subtle voice boost
            {"freq": 1000, "gain": 2},   # Gentle clarity
        ]
    }
}

def build_ffmpeg_filter(preset_name: str, custom_params: Optional[Dict] = None) -> str:
    """Build advanced ffmpeg filter chain for forensic audio processing - OPTIMIZED FOR MINIMAL ARTIFACTS"""
    
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
    
    # 3. GENTLE noise reduction - using anoisesrc instead of afftdn for less artifacts
    if preset["noise_reduction"] > 0:
        nr_strength = preset["noise_reduction"]
        # Use gentler noise reduction with better settings
        filters.append(f"afftdn=nr={nr_strength}:nf=-20:nt=w")  # Changed nf to -20 and added nt=w
    
    # 4. More conservative dynamic range compression
    if preset["dynamic_boost"] > 0:
        ratio = 2 + (preset["dynamic_boost"] / 10)  # Gentler ratios: 2:1 to 4:1
        threshold = -25 + (preset["dynamic_boost"] / 4)  # More conservative threshold
        # Add makeup gain and softer knee
        filters.append(f"acompressor=threshold={threshold}dB:ratio={ratio}:attack=10:release=100:makeup=2:knee=2")
    
    # 5. Equalizer (boost voice frequencies) - More conservative gains
    if preset["eq_bands"]:
        for band in preset["eq_bands"]:
            # Limit EQ gains to prevent artifacts
            limited_gain = max(-10, min(10, band['gain']))
            filters.append(f"equalizer=f={band['freq']}:t=o:g={limited_gain}")
    
    # 6. Voice emphasis (mid-frequency boost) - More conservative
    if preset["voice_emphasis"] > 0:
        voice_freq = 1000
        # Limit voice emphasis to prevent artifacts
        voice_gain = min(6, preset["voice_emphasis"])
        filters.append(f"equalizer=f={voice_freq}:t=o:g={voice_gain}:w=800")  # Wider bandwidth
    
    # 7. Gentle limiter with softer settings
    filters.append("alimiter=level_in=1:level_out=0.95:limit=0.95")
    
    # 8. REMOVE loudnorm as it can introduce artifacts - replace with gentle volume adjustment
    filters.append("volume=1.2")  # Simple 20% volume boost instead
    
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
            logger.error(f"FFmpeg failed with return code {result.returncode}")
            logger.error(f"FFmpeg stderr: {result.stderr}")
            logger.error(f"FFmpeg stdout: {result.stdout}")
            raise Exception(f"FFmpeg processing failed: {result.stderr}")
        
        # Check if output file was created
        if not output_path.exists():
            raise Exception(f"Output file was not created: {output_path}")
        
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
    html_content = """
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
                <button class="preset-btn active" onclick="selectPreset('clean_whisper')">✨ Clean Whisper</button>
                <button class="preset-btn" onclick="selectPreset('gentle_enhance')">🔧 Gentle Enhancement</button>
                <button class="preset-btn" onclick="selectPreset('whisper')">👤 Whisper Mode</button>
                <button class="preset-btn" onclick="selectPreset('breath')">💨 Breath Detection</button>
                <button class="preset-btn" onclick="selectPreset('vocal')">🎵 Vocal Isolation</button>
                <button class="preset-btn" onclick="selectPreset('tv_suppress')">📺 TV Suppression</button>
            </div>
            
            <div class="preset-info" id="preset-info">
                <strong>✨ Clean Whisper:</strong> Minimal processing for very clean whisper enhancement
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
            let audioContext, gainNode, source;
            
            const presets = {
                'whisper': {
                    name: '👤 Whisper Mode',
                    description: 'Optimized for whispers, minimal white noise (30-3500 Hz)'
                },
                'breath': {
                    name: '💨 Breath Detection',
                    description: 'Optimized for breathing, minimal processing (100-2000 Hz)'
                },
                'vocal': {
                    name: '🎵 Vocal Isolation',
                    description: 'Optimized for vocal sounds, balanced processing (80-8000 Hz)'
                },
                'tv_suppress': {
                    name: '📺 TV Suppression',
                    description: 'TV background suppression, minimal artifacts (200-4000 Hz)'
                },
                'clean_whisper': {
                    name: '✨ Clean Whisper',
                    description: 'Minimal processing for very clean whisper enhancement'
                },
                'gentle_enhance': {
                    name: '🔧 Gentle Enhancement',
                    description: 'Minimal processing for slight audio improvement'
                }
            };
            
            function selectPreset(preset) {
                selectedPreset = preset;
                document.querySelectorAll('.preset-btn').forEach(btn => btn.classList.remove('active'));
                event.target.classList.add('active');
                
                const info = presets[preset];
                document.getElementById('preset-info').innerHTML = 
                    '<strong>' + info.name + ':</strong> ' + info.description;
            }
            
            function fileSelected() {
                const file = document.getElementById('audioFile').files[0];
                const fileInfo = document.getElementById('file-info');
                
                if (file) {
                    const size = (file.size / 1024 / 1024).toFixed(2);
                    fileInfo.innerHTML = 
                        '<strong>📄 File:</strong> ' + file.name + '<br>' +
                        '<strong>📊 Size:</strong> ' + size + ' MB<br>' +
                        '<strong>🎵 Type:</strong> ' + file.type;
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
                
                // Convert 0-200 slider range to 0-1 audio range
                const audioVolume = Math.min(volume / 100, 1.0);
                if (audio) {
                    audio.volume = audioVolume;
                }
                
                // Update display
                document.getElementById('volume-display').textContent = volume + '%';
                
                // For volumes > 100%, use Web Audio API for additional gain
                if (volume > 100 && audio && audio.src) {
                    setupAudioGain(audio, volume / 100);
                }
            }
            
            function setupAudioGain(audioElement, gainValue) {
                try {
                    // Only create audio context if we need gain > 1
                    if (gainValue <= 1) return;
                    
                    if (!audioContext) {
                        audioContext = new (window.AudioContext || window.webkitAudioContext)();
                        gainNode = audioContext.createGain();
                        source = audioContext.createMediaElementSource(audioElement);
                        source.connect(gainNode);
                        gainNode.connect(audioContext.destination);
                    }
                    
                    gainNode.gain.value = gainValue;
                } catch (error) {
                    console.warn('Web Audio API not supported for volume boost:', error);
                }
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
                        throw new Error('HTTP error! status: ' + response.status);
                    }
                    
                    updateProgress(90, 'Finalizing...');
                    
                    const blob = await response.blob();
                    const url = URL.createObjectURL(blob);
                    
                    // Set up audio player
                    const audioPlayer = document.getElementById('audioPlayer');
                    audioPlayer.src = url;
                    
                    // Set initial volume properly
                    const volumeSlider = document.getElementById('volumeSlider');
                    const initialVolume = volumeSlider.value;
                    audioPlayer.volume = Math.min(initialVolume / 100, 1.0);
                    
                    // Set up volume boost if needed
                    if (initialVolume > 100) {
                        audioPlayer.addEventListener('loadeddata', () => {
                            setupAudioGain(audioPlayer, initialVolume / 100);
                        });
                    }
                    
                    // Set up download
                    const downloadBtn = document.getElementById('downloadBtn');
                    downloadBtn.href = url;
                    downloadBtn.download = 'processed_' + file.name;
                    
                    // Show result
                    document.getElementById('result').style.display = 'block';
                    updateProgress(100, 'Complete!');
                    
                    // Show processing info
                    document.getElementById('processingInfo').innerHTML = 
                        '<strong>🎚️ Preset:</strong> ' + presets[selectedPreset].name + '<br>' +
                        '<strong>📁 Output:</strong> 44.1kHz 16-bit WAV';
                    
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
    return html_content

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
        logger.info(f"Input file size: {input_path.stat().st_size} bytes")
        
        # Check if FFmpeg is available
        try:
            subprocess.run(["ffmpeg", "-version"], capture_output=True, check=True)
        except (subprocess.CalledProcessError, FileNotFoundError):
            raise HTTPException(status_code=500, detail="FFmpeg is not installed or not working")
        
        # Process audio
        result = await process_audio_file(
            input_path, output_path, preset
        )
        
        if not result["success"]:
            logger.error(f"Processing failed: {result['error']}")
            raise HTTPException(status_code=500, detail=result["error"])
        
        # Check if output file exists and has content
        if not output_path.exists():
            raise HTTPException(status_code=500, detail="Output file was not created")
        
        if output_path.stat().st_size == 0:
            raise HTTPException(status_code=500, detail="Output file is empty")
        
        logger.info(f"Processing successful. Output file size: {output_path.stat().st_size} bytes")
        
        # Return processed file
        return FileResponse(
            path=output_path,
            media_type="audio/wav",
            filename=f"processed_{file.filename}"
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Processing failed: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))
    
    finally:
        # Cleanup temp files (but keep them for debugging if there was an error)
        if input_path.exists():
            try:
                input_path.unlink()
            except:
                pass

@app.get("/debug")
async def debug_info():
    """Debug information endpoint"""
    try:
        # Check FFmpeg
        ffmpeg_result = subprocess.run(["ffmpeg", "-version"], capture_output=True, text=True)
        ffmpeg_version = ffmpeg_result.stdout.split('\n')[0] if ffmpeg_result.returncode == 0 else "Not available"
        
        # Check directory
        temp_files = list(TEMP_DIR.glob("*")) if TEMP_DIR.exists() else []
        
        return {
            "status": "debug",
            "ffmpeg_available": ffmpeg_result.returncode == 0,
            "ffmpeg_version": ffmpeg_version,
            "temp_dir": str(TEMP_DIR),
            "temp_dir_exists": TEMP_DIR.exists(),
            "temp_files": [str(f) for f in temp_files],
            "presets": list(PRESETS.keys())
        }
    except Exception as e:
        return {"error": str(e)}

if __name__ == "__main__":
    # For deployment
    port = int(os.environ.get("PORT", 8000))
    host = os.environ.get("HOST", "0.0.0.0")
    
    print(f"🚀 Starting Forensic Audio Processing Server on {host}:{port}")
    print(f"📁 Temp directory: {TEMP_DIR}")
    print(f"🎚️ Available presets: {list(PRESETS.keys())}")
    
    uvicorn.run(app, host=host, port=port)