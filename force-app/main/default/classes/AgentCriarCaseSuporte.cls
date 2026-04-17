public with sharing class AgentCriarCaseSuporte {

    public class Input {
        @InvocableVariable(label='accountId' required=false)
        public String accountId;

        @InvocableVariable(label='Email do utilizador' required=true)
        public String email;

        @InvocableVariable(label='Assunto' required=true)
        public String assunto;

        @InvocableVariable(label='Descrição do problema' required=true)
        public String descricao;

        @InvocableVariable(label='Tipo (Reclamação / Dúvida / Problema Técnico / Reembolso)' required=false)
        public String tipo;

        @InvocableVariable(label='Order ID relacionado (opcional)' required=false)
        public String orderId;
    }

    public class Output {
        @InvocableVariable(label='Case ID criado')
        public String caseId;

        @InvocableVariable(label='Número do Case (ex: 00001234)')
        public String caseNumber;

        @InvocableVariable(label='Sucesso?')
        public Boolean sucesso;

        @InvocableVariable(label='Mensagem para o chat')
        public String mensagemChat;

        @InvocableVariable(label='Erro')
        public String erroMsg;
    }

    @InvocableMethod(
        label       = 'Agente — Criar Case de Suporte'
        description = 'Cria um Case no Salesforce para acompanhamento pela equipa de suporte quando o agente não consegue resolver o problema.'
        category    = 'GLOBAZ Tickets'
    )
    public static List<Output> criarCase(List<Input> inputs) {
        Output out = new Output();
        try {
            Input inp = inputs[0];

            Case c        = new Case();
            c.Subject     = inp.assunto;
            c.Description = inp.descricao
                + (String.isNotBlank(inp.orderId) ? '\n\nOrder ID: ' + inp.orderId : '')
                + '\n\nEmail do utilizador: ' + inp.email
                + '\n\n[Caso criado pelo Agente GLOBAZ Tickets]';
            c.Origin      = 'Web';
            c.Status      = 'New';
            c.Priority    = 'Medium';

            if (String.isNotBlank(inp.tipo)) {
                c.Type = inp.tipo;
            }

            if (String.isNotBlank(inp.accountId)) {
                try { c.AccountId = (Id) inp.accountId; } catch (Exception ex) {}
            }

            // Tentar associar ao Contact via email
            if (String.isNotBlank(inp.email)) {
                List<Account> accs = [
                    SELECT Id FROM Account
                    WHERE  PersonEmail    = :inp.email
                    AND    IsPersonAccount = true
                    LIMIT  1
                ];
                if (!accs.isEmpty()) c.AccountId = accs[0].Id;
            }

            insert c;

            // Re-query para obter CaseNumber
            c = [SELECT Id, CaseNumber FROM Case WHERE Id = :c.Id LIMIT 1];

            out.sucesso      = true;
            out.caseId       = c.Id;
            out.caseNumber   = c.CaseNumber;
            out.mensagemChat = '✅ Pedido de suporte criado com sucesso!\n\n'
                + '📋 Referência: *#' + c.CaseNumber + '*\n'
                + '📧 Vais receber uma resposta no email *' + inp.email + '* em até 24 horas.\n\n'
                + 'Há mais alguma coisa em que te possa ajudar?';

        } catch (Exception e) {
            out.sucesso      = false;
            out.erroMsg      = e.getMessage();
            out.mensagemChat = '⚠️ Não foi possível criar o pedido de suporte. '
                + 'Por favor contacta-nos diretamente para suporte@globaz.pt';
        }
        return new List<Output>{ out };
    }
}