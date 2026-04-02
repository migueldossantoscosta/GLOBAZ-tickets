public with sharing class AgentReenviarBilhetePDF {

    public class Input {
        @InvocableVariable(label='ID do Bilhete' required=true)
        public String bilheteId;

        @InvocableVariable(label='Account ID do utilizador (para validação)' required=true)
        public String accountId;
    }

    public class Output {
        @InvocableVariable(label='Sucesso?')
        public Boolean sucesso;

        @InvocableVariable(label='Email para o qual foi enviado')
        public String emailEnviado;

        @InvocableVariable(label='Mensagem para o chat')
        public String mensagemChat;

        @InvocableVariable(label='Erro')
        public String erroMsg;
    }

    @InvocableMethod(
        label       = 'Agente — Reenviar Bilhete PDF por Email'
        description = 'Reenvia o bilhete em PDF para o email do cliente. Valida que o bilhete pertence ao utilizador autenticado antes de enviar.'
        category    = 'GLOBAZ Tickets'
    )
    public static List<Output> reenviarBilhete(List<Input> inputs) {
        Output out = new Output();
        try {
            Id bilheteId = (Id) inputs[0].bilheteId;
            Id accId     = (Id) inputs[0].accountId;

            // Validar que o bilhete pertence ao utilizador
            List<Bilhete__c> bilhetes = [
                SELECT Id, Account__c, Account__r.PersonEmail, Account__r.FirstName
                FROM   Bilhete__c
                WHERE  Id         = :bilheteId
                AND    Account__c = :accId
                LIMIT  1
            ];

            if (bilhetes.isEmpty()) {
                out.sucesso      = false;
                out.erroMsg      = 'Bilhete não encontrado ou não pertence a este utilizador.';
                out.mensagemChat = '⚠️ Não encontrei esse bilhete na tua conta.';
                return new List<Output>{ out };
            }

            String emailCliente = bilhetes[0].Account__r.PersonEmail;

            // Invocar o envio de PDF
            EnviarBilhetePDF.enviarEmailFuturo(new List<Id>{ bilheteId });

            out.sucesso      = true;
            out.emailEnviado = emailCliente;
            out.mensagemChat = '📧 Bilhete reenviado com sucesso para *' + emailCliente + '*!\n'
                + 'Verifica também a pasta de spam se não aparecer na caixa de entrada.';

        } catch (Exception e) {
            out.sucesso      = false;
            out.erroMsg      = e.getMessage();
            out.mensagemChat = '⚠️ Não foi possível reenviar o bilhete. '
                + 'Contacta o suporte se o problema persistir.';
        }
        return new List<Output>{ out };
    }
}