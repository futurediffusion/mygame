@echo off
echo === Forzando push desde remoto origin/dev -> origin/main ===
git fetch origin
git push origin refs/remotes/origin/dev:refs/heads/main --force
echo === Push remoto a main completado ===
pause
