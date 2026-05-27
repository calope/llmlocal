# WSL troubleshooting: que hacer cuando se cuelga

Procedimientos antes de reiniciar Windows entero. La mayoria de "WSL reventado"
se resuelve sin reboot.

## Diagnostico de este equipo (2026-05-11)

| Recurso | Valor | Riesgo |
|---|---|---|
| RAM Windows total | 31.6 GB | OK |
| RAM WSL asignada | 22 GB | OK |
| Swap WSL | 16 GB | OK |
| Disco C: total | 477 GB | — |
| **Disco C: libre** | **6.2 GB** | **CRITICO** |
| VHD WSL fisico | 256.89 GB en C: | crece sin compactar si no haces `wsl --shutdown` |
| Uso real dentro WSL | 250 GB | el VHD esta proporcional |
| Docker images dentro WSL | 59.7 GB | ~22 GB reclamables |
| Docker build cache | 45.8 GB | ~16 GB reclamables |

**La causa raiz mas probable** de tus cuelgues que obligan a reiniciar Windows:
C: se queda sin espacio cuando vmcompute intenta expandir el VHD de WSL para
acomodar nuevos datos o crecer la swap interna. Windows tampoco puede crecer su
pagefile (pagefile actual = 22.5 GB en C:). El sistema entero entra en thrashing
hasta que cuelga vmmemWSL → WSL no responde → reiniciar Windows.

## Recuperacion sin reiniciar Windows (orden de menos a mas)

### Nivel 1 — apagado limpio de WSL (PowerShell normal, sin elevacion)

```powershell
wsl --shutdown
```

Esto detiene la VM de forma ordenada. Si tarda mas de 30 s sin volver el prompt,
pasa a nivel 2.

### Nivel 2 — reiniciar servicio Hyper-V vmcompute (PowerShell ELEVADA)

```powershell
Restart-Service vmcompute -Force
```

`vmcompute` es el servicio que gestiona la VM de WSL. Reiniciandolo se libera el
bloqueo en el 80% de los casos. Tras esto:

```powershell
wsl --shutdown   # por si quedo algun residuo
wsl              # arrancar de nuevo
```

### Nivel 3 — matar el proceso vmmemWSL directamente

Si nivel 2 no devuelve el control:

1. Task Manager (Ctrl+Shift+Esc)
2. Pestaña "Detalles" (no "Procesos")
3. Buscar `vmmemWSL` → click derecho → "Finalizar tarea"

O por PowerShell elevada:

```powershell
Stop-Process -Name vmmemWSL -Force
```

Tras eso espera 5 s y `wsl --shutdown && wsl`.

### Nivel 4 — reiniciar todo el subsistema WSL

```powershell
# PowerShell ELEVADA
Stop-Service vmcompute -Force
Stop-Service WslService -Force
Start-Service WslService
Start-Service vmcompute
```

### Nivel 5 — reinicio Windows (ULTIMO recurso)

Solo si nada de lo anterior funciona. En la practica si llegas aqui es porque
C: realmente se quedo sin espacio en disco y el sistema no puede ni manejar el
shutdown limpio.

## Prevencion

### Mantener C: con >30 GB libres

Es la regla principal en este equipo. Mientras tengas <10 GB libres, WSL es
inestable.

Ejecutar la limpieza periodica:

```bash
~/Workspace/llmlocal/scripts/wsl-cleanup.sh           # dry-run
~/Workspace/llmlocal/scripts/wsl-cleanup.sh --execute # ejecutar
```

Tras la limpieza, **siempre**:

```powershell
wsl --shutdown   # desde PowerShell, para que sparseVhd compacte el VHD
```

`sparseVhd=true` esta en tu `.wslconfig`, pero solo compacta al apagar limpio
con `wsl --shutdown`. Sin apagar, el VHD crece y no decrece.

### Limitar lo que metes en el VHD

- **Modelos LLM**: ya estan en `~/Workspace/llmlocal/models/ollama/` (15 GB).
  Si pruebas modelos grandes (70B), valoralos uno a uno, no acumules.
- **Dumps de BD**: `~/Workspace/tinerfe-db/dumps/` ocupa 33 GB. Mueve los .dmp
  historicos a un disco externo si tienes; deja solo el ultimo de cada esquema.
- **Docker**: nunca dejes que el build cache supere 30 GB. Ejecuta
  `docker builder prune -af` cuando termines campañas de builds.

### Monitorizacion preventiva

Lanza esto antes de empezar el dia para detectar drift:

```bash
# Espacio dentro WSL vs disco fisico
df -h /
free -h
docker system df

# Espacio en C: desde WSL
powershell.exe -NoProfile -Command "[math]::Round((Get-PSDrive C).Free/1GB,1)"
```

Si C: cae bajo 20 GB, dispara `wsl-cleanup.sh --execute && wsl --shutdown` ese
mismo dia.

### Solucion a medio plazo: SSD externo USB-C

El SSD del equipo es Micron MTFDKCD512QGN, 477 GB, **el unico disco**. No hay
margen real para mover el VHD a otra unidad.

- **SSD externo USB-C 1-2 TB** (Samsung T7 / Crucial X9 Pro): 80-150 €
- Permite mover el VHD ahi con `wsl --export` + `wsl --import` y dejar C: holgado
- Velocidad NVMe externa = ~1 GB/s, suficiente para WSL aunque algo menos que interno

Procedimiento (cuando tengas el SSD montado como D:):

```powershell
# 1. Backup
wsl --export Ubuntu D:\backup\ubuntu-backup.tar

# 2. Unregister (NO borra el .tar)
wsl --unregister Ubuntu

# 3. Import en la unidad nueva
wsl --import Ubuntu D:\wsl\Ubuntu D:\backup\ubuntu-backup.tar --version 2

# 4. Configurar usuario default
ubuntu config --default-user clp   # o el comando equivalente para tu distro
```

Tras eso C: recupera 250 GB y el VHD vive en D:.

## Casos especificos vistos en este equipo

- **WSL cuelga durante pull de imagen Docker grande**: causa probable, el pull
  intentó expandir el VHD y C: estaba bajo en espacio. Verificar C: antes de
  pulls >5 GB.
- **WSL cuelga durante compilacion pesada (cargo/maven/webpack)**: similar; el
  build cache crece y satura. Hacer cleanup antes de builds grandes.
- **WSL cuelga sin razon aparente**: revisar Event Viewer Windows
  (`Get-WinEvent -LogName Application -ProviderName Hyper-V*`). Si no hay
  eventos, suele ser saturacion de C: silenciosa.
