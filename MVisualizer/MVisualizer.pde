// Particle Audio Visualizer (Processing)
// Requires the Processing "Sound" library: Sketch > Import Library > Manage Libraries > search "Sound"
// Put your song and logo in this sketch's "data" folder.

import processing.sound.*;

// ---------- Settings you'll most likely change ----------
String SONG_FILE = "Between the Storms 146bpm Bm.mp3";
String LOGO_FILE = "ARKAID_LOGO_WHITE.png";   // optional — sketch runs without it
int    LOGO_WIDTH = 200;
// --------------------------------------------------------

SoundFile soundFile;
Amplitude amp;
FFT fft;

int particleCount = 800;
Particle[] particles;
int bands = 64;
float[] frequencySensitivity;

float smoothedAmplitude = 0;
float smoothingFactor = 0.1;
float baseRadius = 250;
float smoothedBackground = 0;

// Logo "pulse" (grows on the beat, no movement)
float smoothedLogoScale = 1.0;
PImage logo;

void setup() {
  size(800, 800);
  colorMode(RGB, 255, 255, 255, 100);
  strokeCap(PROJECT);   // sharp line ends
  imageMode(CENTER);
  hint(ENABLE_TEXTURE_MIPMAPS);

  logo = loadImage(LOGO_FILE);
  if (logo != null) logo.resize(LOGO_WIDTH, 0);

  soundFile = new SoundFile(this, SONG_FILE);
  amp = new Amplitude(this);
  fft = new FFT(this, bands);

  soundFile.loop();
  amp.input(soundFile);
  fft.input(soundFile);

  // Turn down the sub-bass so particles react to the mids/highs
  frequencySensitivity = new float[bands];
  for (int i = 0; i < bands; i++) {
    float frequency = map(i, 0, bands - 1, 20, 20000);
    if (frequency < 60) {
      frequencySensitivity[i] = 0.15;
    } else if (frequency < 250) {
      frequencySensitivity[i] = map(frequency, 60, 250, 0.15, 1.2);
    } else if (frequency < 4000) {
      frequencySensitivity[i] = 1.5;
    } else {
      frequencySensitivity[i] = 1.2;
    }
  }

  particles = new Particle[particleCount];
  for (int i = 0; i < particleCount; i++) {
    particles[i] = new Particle();
  }
}

void draw() {
  fft.analyze();

  // ----- Overall energy (skipping the lowest band) drives the background flash -----
  float energy = 0;
  int used = 0;
  for (int i = 1; i < bands; i++) {
    energy += fft.spectrum[i] * 1.2;
    used++;
  }
  energy /= used;

  float thresholdEnergy = 0.035;
  float backgroundIntensity = 0;
  if (energy > thresholdEnergy) {
    backgroundIntensity = constrain(map(energy, thresholdEnergy, 0.15, 0, 160), 0, 160);
  }
  // Fast attack, slower release
  float bgSpeed = (backgroundIntensity > smoothedBackground) ? 0.2 : 0.1;
  smoothedBackground += (backgroundIntensity - smoothedBackground) * bgSpeed;

  background(smoothedBackground,
             max(0, smoothedBackground - 100),
             max(0, smoothedBackground - 120));

  translate(width / 2, height / 2);

  float currentAmplitude = amp.analyze();
  smoothedAmplitude += (currentAmplitude - smoothedAmplitude) * smoothingFactor;

  for (Particle p : particles) {
    p.update(smoothedAmplitude, fft.spectrum);
    p.display();
  }

  // ----- Logo: gets bigger with the kick/bass, same feel as the background -----
  if (logo != null) {
    float bassEnergy = (fft.spectrum[0] + fft.spectrum[1]) / 2.0;   // lowest bands = kick/bass
    float punch = max(bassEnergy, energy * 1.5);
    float targetScale = constrain(map(punch, 0, 0.15, 1.0, 1.15), 1.0, 1.15);

    float logoSpeed = (targetScale > smoothedLogoScale) ? 0.3 : 0.08;  // snap up, ease down
    smoothedLogoScale += (targetScale - smoothedLogoScale) * logoSpeed;

    pushMatrix();
    scale(smoothedLogoScale);
    tint(255, 220);
    image(logo, 0, 0);
    popMatrix();
    noTint();
  }

  filter(BLUR, 1);
}

class Particle {
  float angle, dist, size, baseSpeed, distBase, redValue;
  int freqBand;

  Particle() {
    angle = random(TWO_PI);
    distBase = random(baseRadius - 50, baseRadius + 50);
    dist = distBase;
    size = random(3.5, 4);
    baseSpeed = random(0.005, 0.02);
    freqBand = int(random(bands));
    redValue = random(50, 255);
  }

  void update(float amplitude, float[] spectrum) {
    float freqAmplitude = spectrum[freqBand] * frequencySensitivity[freqBand];
    float amplifiedSpeed = baseSpeed + amplitude * 0.05;

    float freqInfluence = sin(frameCount * amplifiedSpeed) * (freqAmplitude * 40);
    dist = distBase + freqInfluence;

    size = map(freqAmplitude * amplitude, 0, 0.1, 3.5, 5.5);
    redValue = map(freqAmplitude, 0, 0.1, 50, 255);
    angle += baseSpeed + (freqAmplitude * 0.1);
  }

  void display() {
    float x = cos(angle) * dist;
    float y = sin(angle) * dist;
    float h = size * 0.7;

    // Glow
    stroke(redValue * 0.4, 0, 0, 25);
    strokeWeight(size * 0.3);
    line(x - h, y - h, x + h, y + h);   // single diagonal "\"

    // Main line
    stroke(redValue, 0, 0, 80);
    strokeWeight(size * 0.2);
    line(x - h, y - h, x + h, y + h);
  }
}
