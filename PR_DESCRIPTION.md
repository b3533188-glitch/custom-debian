# Fix: Corrige wallpaper preto no Sway e implementa troca automática

## 🎯 Resumo

Esta PR corrige o problema de wallpaper preto no Sway e implementa a funcionalidade completa de troca automática de wallpapers a cada 30 minutos, com suporte a wallpapers diurnos/noturnos.

## 🐛 Problemas Corrigidos

### 1. Wallpaper Preto ao Iniciar
**Causa:** Daemon de wallpaper não estava sendo iniciado
**Solução:** Adicionada linha `exec` no config do Sway para iniciar o daemon

### 2. Duplicação de Daemon via Systemd
**Causa:** `setup_user_systemd_session()` tentava enable/start todos os services
**Solução:** Adicionado código para parar, desabilitar e pular o `sway-wallpaper.service`

### 3. Daemon Não Rodava em Background
**Causa:** Faltava `&` no final da linha exec, bloqueando o startup do Sway
**Solução:** Adicionado `&` para executar daemon em background

## ✨ Novas Funcionalidades

### Script de Instalação Manual
- Detecta automaticamente usuário e perfil
- Instala configurações sem precisar rodar main.sh completo
- Útil para aplicar apenas correções de wallpaper

## 📝 Commits

1. **8ac4717** - Fix: Corrige wallpaper preto no Sway - inicia daemon via config
2. **39ef02f** - Fix: Previne duplicação do daemon wallpaper via systemd
3. **1faaa7d** - Add: Script de instalação manual do fix de wallpaper
4. **8df8c37** - Fix: Executa daemon wallpaper em background (adiciona &)

## 📦 Arquivos Alterados

### Configurações (todos os perfis: mac, notebook, qemu)
- `config.*/sway/config`: Adiciona exec do daemon (com &)
- `config.*/systemd/sway-wallpaper.service`: Desabilita auto-start, corrige variáveis

### Scripts de Instalação
- `lib/configure.sh`: Previne duplicação do daemon via systemd
- `install-wallpaper-fix.sh`: Novo script de instalação rápida

**Total:** 8 arquivos alterados, 217 inserções(+), 13 deleções(-)

## 🧪 Como Testar

```bash
# Opção 1: Via main.sh
sudo ./main.sh  # Escolher: configs

# Opção 2: Via script de instalação rápida
sudo ./install-wallpaper-fix.sh

# Verificar funcionamento
pgrep -fa sway-wallpaper-daemon
pgrep -fa swaybg
tail -f ~/.local/state/sway/wallpaper-daemon.log
```

## ✅ Resultado Esperado

- ✅ Wallpaper aparece ao iniciar Sway (não fica preto)
- ✅ Daemon roda em background
- ✅ Wallpaper muda automaticamente a cada 30 minutos
- ✅ Wallpaper muda entre dia/noite às 06:00 e 18:00
- ✅ Apenas uma instância do daemon rodando (sem duplicação)

## 📊 Arquitetura da Solução

```
Sway startup
    ↓
exec initial-wallpaper.sh        → Define wallpaper inicial
    ↓
exec sway-wallpaper-daemon.sh &  → Inicia daemon em background
    ↓
Daemon loop infinito:
  ├─ Executa change-wallpaper.sh (a cada 30 min)
  │   ├─ Detecta hora (dia: 6-18, noite: 18-6)
  │   ├─ Seleciona wallpaper aleatório do diretório correto
  │   ├─ Atualiza symlink wallpaper_current
  │   └─ Inicia novo swaybg ANTES de matar antigo (sem tela preta)
  │
  ├─ Detecta transições 06:00/18:00 (troca imediata)
  └─ Repete infinitamente
```

## 🔗 Issue Relacionada

Esta PR resolve o problema reportado de wallpaper preto após instalação/atualização do sistema.

## 🎨 Screenshots

### Antes
- ❌ Tela preta ao iniciar Sway
- ❌ Wallpaper não muda automaticamente

### Depois
- ✅ Wallpaper aparece imediatamente
- ✅ Troca automática a cada 30 minutos
- ✅ Troca automática dia/noite
