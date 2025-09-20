# 📢 NewsBuddies  

**Making politics simple, fun, and understandable for kids!**  

---

## 🏆 Hackathon Win!  
We are a team of **9th graders** who built **NewsBuddies** — and we are proud to announce that we **WON the Zoho Hackathon 2025(https://www.cognihacks.com/)!** 🎉  

Out of about 150 participants, ranging from high school seniors to university students such as Georgia Tech, our team was grateful to win first place with a standalone app and hardware solution we created.

---

## 👥 Team  
- **Nikhil Konduru** – Raspberry Pi integrations, final hardware solution, Flutter app development, core Android features, multithreading for button-controlled news playback  
- **Arnav Garg** – Hardware/Software integration and testing sequences. 
- **Aditya Gaur** – App development and presentation creation.

---

## 🌟 Inspiration  
News is confusing — even for adults. Kids often struggle with terms like *tariffs*, *congress*, or *president*. Our mission was to make News easier to understand by **breaking down complex ideas with fun analogies** (e.g., *a president is like the captain of a pirate ship*).  

---

## 📱 What It Does  
NewsBuddies has **two components**:  

### 1. **The Mobile App (Flutter + Android)**  
- Kids input their **age** and **interests**  
- They get **curated political articles** rewritten into simple, easy-to-understand language  
- A **chatbot** (powered by LLMs) helps answer any lingering questions based on the article context  
- Kids can **like** stories → Parents can see what their child enjoyed in the **parent dashboard**  

### 2. **The Hardware Device (Raspberry Pi)**  
- For parents who prefer **device-free learning**  
- News is **spoken aloud** via a Bluetooth speaker  
- Controlled with **physical buttons** + displayed instructions on an **OLED screen**  
- Customizes articles by **age and interest**  
- Allows **family listening** without distractions from YouTube/TikTok/etc.  

---

## 🔧 How We Built It  
### **App Development (Flutter)**  
- Built with **Flutter + Dart**  
- Integrated with **NewsAPI.org** to fetch articles  
- Used **Ollama + LLM APIs** to simplify content  
- Chatbot integration for **article-specific questions**  

### **Hardware Development (Raspberry Pi)**  
- **Python**-based system on Raspberry Pi 4  
- Tools & Libraries: `NewsAPI`, `Newspaper3k`, `ElevenLabs`, `ChatGPT`, `Pillow`, `I2C`, `multithreading`  
- Components: Raspberry Pi 4B, Bluetooth speaker, OLED display (SSD1306), push buttons, breadboard, jumper wires, PiSugar, power bank  

---

## ⚡ Challenges  
- SSH issues: Raspberry Pi wouldn’t connect to WiFi → required network debugging & port adjustments  
- I2C display interference from PiSugar pins → solved by reconfiguring connections  
- Debugging new hardware problems we had never faced before  

---

## 🏅 Accomplishments  
- A **cohesive, fully working mobile + hardware product**  
- Solved real-world problems with **creativity + perseverance**  
- Learned advanced debugging, hardware-software integration, and app-hardware sync  

---

## 📚 What We Learned  
- Electrical interference troubleshooting  
- OLED display usage (first time!)  
- Network protocols & SSH debugging  
- Importance of **multithreading** for smooth user control  

---

## 🚀 What’s Next for NewsBuddies  
- Personalized recommendations (like YouTube’s “For You” feed)  
- Hardware enclosure for a compact, sleek look  
- iOS app support  
- Performance optimizations with lighter ML models  
- Push notifications for background-loaded articles  

---

## 🛠️ Built With  
- **Android Studio**  
- **Flutter + Dart**  
- **NewsAPI.org**  
- **Newspaper3k**  
- **Ollama**  
- **ChatGPT + Claude**  
- **ElevenLabs (TTS)**  
- **Raspberry Pi 4**  
- **SSD1306 OLED Display**  
- **Python + Pillow + Multithreading**  

---

## 🔗 Links  
- 📖 **Devpost:** [https://devpost.com/software/923132](https://devpost.com/software/newsbuddies-delivering-accessible-news-to-children)  
- 💻 **GitHub Repo:** [https://github.com/NikhilKonduru8/NewsBuddiesZohoHackthonWin](https://github.com/NikhilKonduru8/NewsBuddiesZohoHackthonWin)  

---

<p align="center">✨ Built with passion by 9th graders: Nikhil Konduru, Arnav Garg, Aditya Gaur ✨</p>
