@echo off
cd /d D:\IA\mygame
echo === Subiendo cambios locales a origin/dev ===
git add .
git commit -m "update desde local"
git push origin dev
echo === Push completado exitosamente ===
pause
