@echo off
cd /d D:\IA\mygame
echo === Forzando que el local coincida con origin/dev ===
git fetch origin
git reset --hard origin/main
echo === Sincronización completa. El local ahora es idéntico a origin/main ===
pause
