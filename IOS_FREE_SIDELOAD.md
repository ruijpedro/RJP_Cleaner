# RJP Cleaner — iOS gratuito / sideload

Esta variante não usa TestFlight nem exige a subscrição paga Apple Developer Program.

## Android
1. GitHub > Actions > **Android APK** > **Run workflow**.
2. No fim, abre a execução e descarrega o artifact **RJP-Cleaner-Android-APK**.
3. Extrai o ZIP do artifact e instala o `.apk` no Android.

## iPhone — opção gratuita oficial com Xcode
Requisitos: um Mac, Xcode e uma Apple ID gratuita.

1. No Mac, descarrega/clona este repositório.
2. Abre Terminal na pasta `iOS` e instala XcodeGen se necessário: `brew install xcodegen`.
3. Executa `xcodegen generate`.
4. Abre `RJPCleaner.xcodeproj` no Xcode.
5. Liga o iPhone ao Mac e seleciona-o como destino.
6. Em **Signing & Capabilities**, ativa **Automatically manage signing**.
7. Em **Team**, escolhe a tua Apple ID / **Personal Team**.
8. Se o Xcode indicar que o Bundle Identifier já existe, muda `pt.rjp.cleaner.ios` para algo único, por exemplo `pt.rjp.cleaner.ios.ruijpedro`.
9. Carrega em **Run (▶)** para instalar no iPhone.
10. Se o iPhone pedir confiança/Developer Mode, segue a indicação apresentada pelo próprio iOS em Definições e volta a executar a app.

### Limitação da conta gratuita
A instalação assinada por uma **Personal Team** é para desenvolvimento pessoal e tem validade limitada; o Xcode poderá obrigar a voltar a instalar/assinar periodicamente. Não cria um link público tipo APK e não permite TestFlight.

## iPhone sem Mac
O workflow **iOS Build** do GitHub apenas valida que o código compila para simulador. Um `.app` de simulador não é instalável num iPhone real. Para sideload num iPhone físico continua a ser necessária uma assinatura válida associada ao dispositivo. Ferramentas de sideload de terceiros podem simplificar a renovação, mas não removem as regras de assinatura da Apple.

## Segurança
O RJP Cleaner não elimina automaticamente fotos ou vídeos pessoais sem confirmação. No iOS, a app só gere a Fototeca autorizada e pastas que o utilizador selecionar explicitamente.
