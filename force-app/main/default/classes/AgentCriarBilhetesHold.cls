public with sharing class AgentCriarBilhetesHold {

    public class Input {
        @InvocableVariable(label='eventId' required=true)
        public String eventId;

        @InvocableVariable(label='orderId' required=true)
        public String orderId;

        @InvocableVariable(label='seats' required=true)
        public List<SeatInfo> seats;
    }

    public class SeatInfo {
        @InvocableVariable public String fila;
        @InvocableVariable public Decimal numeroLugar;
    }

    public class Output {
        @InvocableVariable(label='createdTicketIds')
        public List<String> createdTicketIds;

        @InvocableVariable(label='sucesso')
        public Boolean sucesso;
    }

    @InvocableMethod(
        label       = 'Agente — Criar Bilhetes em Hold'
        description = 'Cria os registos de bilhete em estado Hold para bloquear os lugares temporariamente.'
        category    = 'GLOBAZ Tickets'
    )
    public static List<Output> criarHold(List<Input> inputs) {
        Output out = new Output();
        out.createdTicketIds = new List<String>();
        out.sucesso = false;

        try {
            Input inp = inputs[0];
            List<Bilhete__c> bilhetesHold = new List<Bilhete__c>();

            // Buscar a conta associada à Order
            List<Order> ords = [SELECT AccountId FROM Order WHERE Id = :inp.orderId LIMIT 1];
            Id accId = !ords.isEmpty() ? ords[0].AccountId : null;

            for (SeatInfo seat : inp.seats) {
                bilhetesHold.add(new Bilhete__c(
                    Evento__c        = inp.eventId,
                    Order__c         = inp.orderId,
                    Account__c       = accId,
                    Fila__c          = seat.fila,
                    NumeroLugar__c   = seat.numeroLugar,
                    EstadoBilhete__c = 'Hold'
                ));
            }

            if (!bilhetesHold.isEmpty()) {
                insert bilhetesHold;
                for (Bilhete__c b : bilhetesHold) {
                    out.createdTicketIds.add(b.Id);
                }
                out.sucesso = true;
            }

        } catch (Exception e) {
            System.debug('Erro ao criar bilhetes em Hold: ' + e.getMessage());
        }

        return new List<Output>{ out };
    }
}
