public without sharing class GLO_BulkCancelAction {

    public class Input {
        @InvocableVariable(label='Email User' required=true)
        public String emailUser;
    }

    public class Output {
        @InvocableVariable(label='Mensagem Chat')
        public String mensagemChat;
    }

    /**
     * @description Versão Ultra-Leve com CADEADO de Execução.
     */
    @InvocableMethod(
        label       = 'GLOBAZ — Cancelamento Ultra-Rápido'
        description = 'Executa o cancelamento de bilhetes e fornece o código RESULTADO_REAL_DML.'
        category    = 'GLO_Tickets'
    )
    public static List<Output> executeQuickCancel(List<Input> inputs) {
        Output out = new Output();
        if (inputs == null || inputs.isEmpty()) {
            out.mensagemChat = 'ERRO: Input vazio';
            return new List<Output>{ out };
        }
        
        String email = inputs[0].emailUser.trim().toLowerCase();
        System.debug('### GLO_LOG: Executando DML para ' + email);
        
        try {
            List<Bilhete__c> tickets = [
                SELECT Id FROM Bilhete__c 
                WHERE  Account__r.PersonEmail = :email
                AND    EstadoBilhete__c = 'Vendido'
                LIMIT 50
            ];

            if (tickets.isEmpty()) {
                out.mensagemChat = 'ERRO: ZERO_BILHETES_ENCONTRADOS';
                return new List<Output>{ out };
            }

            for (Bilhete__c t : tickets) {
                t.EstadoBilhete__c = 'Cancelado';
            }
            update tickets;

            // Retorno único para GATING de Roteamento
            if (tickets.size() > 0) {
                out.mensagemChat = 'DML_SUCCESS:' + tickets.size();
                System.debug('### GLO_LOG: SUCESSO. Registos: ' + tickets.size());
            } else {
                out.mensagemChat = 'ERRO:ZERO_REGISTOS';
            }

        } catch (Exception e) {
            out.mensagemChat = 'ERRO:' + e.getMessage();
            System.debug('### GLO_LOG: FALHA: ' + e.getMessage());
        }

        return new List<Output>{ out };
    }
}
