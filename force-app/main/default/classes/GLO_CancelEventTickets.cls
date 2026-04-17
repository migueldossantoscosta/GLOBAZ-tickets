public without sharing class GLO_CancelEventTickets {
    
    public class Input {
        @InvocableVariable(label='Email User' required=true)
        public String emailUser;

        @InvocableVariable(label='Nome do Evento' required=true)
        public String nomeEvento;
    }

    public class Output {
        @InvocableVariable(label='Resultado Técnico')
        public String resultado;
    }

    @InvocableMethod(
        label       = 'GLOBAZ — Cancelar Bilhetes por Evento'
        description = 'Altera o estado para Cancelado filtrando por email e nome do evento.'
        category    = 'GLO_Tickets'
    )
    public static List<Output> executeCancel(List<Input> inputs) {
        Output out = new Output();
        if (inputs == null || inputs.isEmpty()) return new List<Output>{ out };
        
        String email = inputs[0].emailUser.trim().toLowerCase();
        String evento = inputs[0].nomeEvento;

        try {
            // 1. Query Síncrona Rigorosa
            List<Bilhete__c> tickets = [
                SELECT Id, EstadoBilhete__c 
                FROM   Bilhete__c 
                WHERE  Account__r.PersonEmail = :email
                AND    Evento__r.Name = :evento
                AND    EstadoBilhete__c = 'Vendido'
            ];

            if (tickets.isEmpty()) {
                out.resultado = 'ERRO:ZERO_REGISTOS';
                return new List<Output>{ out };
            }

            // 2. Preparação dos Dados
            for (Bilhete__c t : tickets) {
                t.EstadoBilhete__c = 'Cancelado';
            }

            // 3. Execução DML
            update tickets;

            // 4. Verificação de Integridade (Opcional, mas solicitado)
            out.resultado = 'OK:' + tickets.size();

        } catch (Exception e) {
            out.resultado = 'ERRO:' + e.getMessage();
        }

        return new List<Output>{ out };
    }
}
