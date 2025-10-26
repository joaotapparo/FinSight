# Configuração do Supabase para Finsight

## Passos para configurar o Supabase:

### 1. Criar projeto no Supabase

1. Acesse [supabase.com](https://supabase.com)
2. Crie uma nova conta ou faça login
3. Clique em "New Project"
4. Escolha sua organização e dê um nome ao projeto
5. Defina uma senha para o banco de dados
6. Escolha uma região próxima a você

### 2. Obter as credenciais

1. No painel do Supabase, vá para Settings > API
2. Copie a **Project URL** e a **anon public** key

### 3. Configurar o arquivo .env

1. Abra o arquivo `.env` na raiz do projeto
2. Substitua os valores pelos seus dados do Supabase:

```
SUPABASE_URL=https://seu-projeto.supabase.co
SUPABASE_ANON_KEY=sua_chave_anonima_aqui
```

### 4. Configurar autenticação no Supabase

1. No painel do Supabase, vá para Authentication > Settings
2. Em "Site URL", adicione: `http://localhost:3000` (para desenvolvimento)
3. Em "Redirect URLs", adicione: `http://localhost:3000/**`

### 5. Executar o projeto

```bash
flutter pub get
flutter run
```

## Funcionalidades implementadas:

### Tela de Login:

✅ **Login com Supabase**: Autenticação real usando email e senha
✅ **Validação de formulário**: Validação de email e senha
✅ **Tratamento de erros**: Mensagens de erro específicas do Supabase
✅ **Loading states**: Indicador de carregamento durante o login
✅ **UI melhorada**: Interface mais moderna e responsiva

### Tela de Registro:

✅ **Registro com Supabase**: Criação de contas usando email e senha
✅ **Validação completa**: Email, senha e confirmação de senha
✅ **Confirmação de senha**: Validação para garantir que as senhas coincidem
✅ **Toggle de visibilidade**: Botões para mostrar/ocultar senhas
✅ **Tratamento de erros específicos**: Mensagens personalizadas para cada tipo de erro
✅ **UI responsiva**: Interface moderna com SingleChildScrollView
✅ **Feedback visual**: SnackBars informativos para sucesso e erro

## Próximos passos sugeridos:

- Adicionar recuperação de senha
- Implementar logout
- Adicionar persistência de sessão
- Criar tela de perfil do usuário
- Implementar verificação de email
