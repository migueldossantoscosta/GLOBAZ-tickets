public with sharing class AgentReenviarBilhetePDF {
    // Definir entrada para o bot reenviar o PDF do bilhete


    public class Input {
        @InvocableVariable(label='ID do Bilhete' required=true)
        public String bilheteId;

        @InvocableVariable(label='accountId' required=true)
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
        description = 'Reenvia o bilhete em PDF para o email do cliente. Suporta tanto o ID técnico (a01...) como o Nome visível (LOB-...).'
        category    = 'GLOBAZ Tickets'
    )
    public static List<Output> reenviarBilhete(List<Input> inputs) {
        Output out = new Output();
        try {
            String bilheteIdentificador = inputs[0].bilheteId;
            Id accIdVal = (Id) inputs[0].accountId;

            // 1. Tentar encontrar o bilhete por ID ou por Name (LOB-...)
            List<Bilhete__c> bilhetes;
            
            // Verifica se o identificador parece um ID do Salesforce
            Boolean isId = false;
            try {
                Id.valueOf(bilheteIdentificador);
                isId = true;
            } catch (Exception e) {
                isId = false;
            }

            if (isId) {
                bilhetes = [
                    SELECT Id, Name, Account__c, Account__r.PersonEmail, Account__r.FirstName
                    FROM   Bilhete__c
                    WHERE  Id         = :bilheteIdentificador
                    AND    Account__c = :accIdVal
                    LIMIT  1
                ];
            } else {
                bilhetes = [
                    SELECT Id, Name, Account__c, Account__r.PersonEmail, Account__r.FirstName
                    FROM   Bilhete__c
                    WHERE  Name       = :bilheteIdentificador
                    AND    Account__c = :accIdVal
                    LIMIT  1
                ];
            }

            if (bilhetes.isEmpty()) {
                out.sucesso      = false;
                out.erroMsg      = 'Bilhete não encontrado ou não pertence a este utilizador.';
                out.mensagemChat = '⚠️ Não encontrei o bilhete "' + bilheteIdentificador + '" na tua conta. Podes confirmar o número?';
                return new List<Output>{ out };
            }

            String emailCliente = bilhetes[0].Account__r.PersonEmail;
            Id bilheteRealId   = bilhetes[0].Id;

            // 2. Invocar o envio de PDF (usando o ID real encontrado)
            EnviarBilhetePDF.enviarEmailFuturo(new List<Id>{ bilheteRealId });

            out.sucesso      = true;
            out.emailEnviado = emailCliente;
            out.mensagemChat = '📧 O bilhete *' + bilhetes[0].Name + '* foi reenviado para *' + emailCliente + '*!\n'
                + 'Deve chegar dentro de instantes. Verifica também a pasta de spam.';

        } catch (Exception e) {
            out.sucesso      = false;
            out.erroMsg      = e.getMessage();
            out.mensagemChat = '⚠️ Ocorreu um erro ao tentar reenviar o bilhete: ' + e.getMessage();
        }
        return new List<Output>{ out };
    }
}