# RJP Cleaner V1.1 — Android + iOS

Projeto multiplataforma com implementações nativas.

## Android
Código em `Android/`. Mantém a versão Android com análise de armazenamento, ficheiros grandes, APKs, duplicados e conteúdo multimédia acessível.

## iOS
Código SwiftUI em `iOS/`. Funcionalidades:
- análise da Fototeca autorizada pelo utilizador;
- ordenação de fotos/vídeos por tamanho;
- procura de duplicados exatos numa amostra de até 250 itens;
- seleção e eliminação de fotos/vídeos, com confirmação do iOS;
- escolha de uma pasta através da app Ficheiros;
- análise recursiva de ficheiros da pasta autorizada;
- seleção e eliminação de ficheiros dessa pasta;
- interface RJP Cleaner com dashboard, Fotos e Ficheiros.

### Limitações iOS
O iOS não permite a uma app percorrer livremente o armazenamento privado de outras apps. Assim, a versão iOS não tenta aceder diretamente às pastas privadas do WhatsApp, Instagram, etc. A gestão é feita através da Fototeca e de pastas explicitamente escolhidas pelo utilizador no seletor de documentos.

## GitHub Actions
- `Android APK`: gera APK debug.
- `iOS Build`: valida a compilação num simulador iOS. Para instalar num iPhone ou publicar na App Store é necessária assinatura Apple (Apple Developer Team / certificados / provisioning).

## Bundle IDs
- Android: `pt.rjp.cleaner`
- iOS: `pt.rjp.cleaner.ios`

## V1.2 — Ícone oficial RJP Cleaner
- Ícone oficial integrado no Android (mipmap + adaptive icon).
- AppIcon completo integrado no iOS Assets.xcassets.
- Ícones 1024 px para Play Store/App Store em `release-assets/`.
