@echo off
cd /d D:\IA\mygame
echo === Subiendo cambios locales a origin/dev (FORZADO) ===
git add .
git commit -m "update desde local"
git push origin HEAD:dev --force
echo === Push completado exitosamente (forzado) ===
pause
