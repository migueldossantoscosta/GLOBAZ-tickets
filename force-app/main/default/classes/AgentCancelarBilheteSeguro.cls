public with sharing class AgentCancelarBilheteSeguro {
    
    public class Input {
        @InvocableVariable(label='ID da Reserva (Order) - Opcional se Bulk')
        public String orderId;

        @InvocableVariable(label='Código do Lugar (ex: B15) - Opcional se Bulk')
        public String seatNumber;

        @InvocableVariable(label='Cancelar TODOS os bilhetes futuros?')
        public Boolean cancelAll;

        @InvocableVariable(label='accountId (Obrigatório para Bulk)')
        public String accountId;

        @InvocableVariable(label='Email do Utilizador (Alternativa para Bulk)')
        public String emailUser;
    }

    public class Output {
        @InvocableVariable(label='Sucesso?')
        public Boolean sucesso;

        @InvocableVariable(label='Mensagem para o chat')
        public String mensagemChat;

        @InvocableVariable(label='Total de bilhetes cancelados')
        public Integer totalCancelados;

        @InvocableVariable(label='Erro')
        public String erroMsg;
    }

    @InvocableMethod(
        label       = 'Agente — Cancelar Bilhete com Seguro'
        description = 'Realiza o cancelamento (Update para Cancelado) de um bilhete ou de todos os bilhetes futuros com seguro.'
        category    = 'GLOBAZ Tickets'
    )
    public static List<Output> processCancellation(List<Input> inputs) {
        Output out = new Output();
        out.sucesso = false;
        out.totalCancelados = 0;

        try {
            if (inputs == null || inputs.isEmpty()) return new List<Output>{ out };
            Input inp = inputs[0];

            // --- LÓGICA DE CANCELAMENTO EM MASSA (BULK) ---
            if (inp.cancelAll == true) {
                if (String.isBlank(inp.accountId) && String.isBlank(inp.emailUser)) {
                    out.erroMsg = 'IDENTIFICATION_MISSING';
                    out.mensagemChat = '⚠️ Não consegui identificar o perfil (ID ou Email) para cancelar os bilhetes.';
                    return new List<Output>{ out };
                }

                // Query abrangente por ID ou Email
                List<Bilhete__c> bilhetesBulk = [
                    SELECT Id, EstadoBilhete__c 
                    FROM   Bilhete__c 
                    WHERE  (Account__c = :inp.accountId OR Account__r.PersonEmail = :inp.emailUser)
                    AND    EstadoBilhete__c = 'Vendido' 
                    AND    Evento__r.DataEvento__c >= TODAY 
                    AND    Order__r.HasInsurance__c = true
                ];

                if (bilhetesBulk.isEmpty()) {
                    out.sucesso = true;
                    out.mensagemChat = 'Não encontrei nenhum bilhete futuro com seguro ativo para ser reembolsado. 🧐';
                    return new List<Output>{ out };
                }

                for(Bilhete__c b : bilhetesBulk) {
                    b.EstadoBilhete__c = 'Cancelado';
                }
                
                Database.update(bilhetesBulk, true);
                
                out.sucesso = true;
                out.totalCancelados = bilhetesBulk.size();
                out.mensagemChat = 'Processado! Todos os teus bilhetes para eventos futuros com seguro foram cancelados e os lugares libertados. Receberás a confirmação do reembolso em breve.';
                return new List<Output>{ out };
            }

            // --- LÓGICA DE CANCELAMENTO INDIVIDUAL ---
            if (String.isBlank(inp.orderId)) {
                out.erroMsg = 'ORDER_ID_MISSING';
                out.mensagemChat = '⚠️ ID da reserva não fornecido.';
                return new List<Output>{ out };
            }

            Id targetOrderId = (Id)inp.orderId;
            String seatRaw = inp.seatNumber != null ? inp.seatNumber.trim().toUpperCase() : '';
            
            if (String.isBlank(seatRaw)) {
                out.erroMsg = 'LUGAR_INVALIDO';
                out.mensagemChat = '⚠️ Por favor, indica o código do lugar que pretendes cancelar (ex: B15).';
                return new List<Output>{ out };
            }

            String filaStr = '';
            String numeroStr = '';
            for (Integer i = 0; i < seatRaw.length(); i++) {
                String c = seatRaw.substring(i, i+1);
                if (c.isAlpha()) filaStr += c;
                else if (c.isNumeric()) numeroStr += c;
            }

            if (String.isBlank(filaStr) || String.isBlank(numeroStr)) {
                 out.erroMsg = 'FORMATO_LUGAR_INVALIDO';
                 out.mensagemChat = '⚠️ O formato do lugar não é reconhecido. Usa algo como "B15".';
                 return new List<Output>{ out };
            }
            Integer seatNum = Integer.valueOf(numeroStr);

            List<Order> ords = [
                SELECT HasInsurance__c, Evento__r.DataEvento__c, Evento__r.Name, Evento__r.Recinto__r.Name, Evento__r.PrecoBilhete__c 
                FROM Order 
                WHERE Id = :targetOrderId 
                LIMIT 1
            ];
            
            if (ords.isEmpty()) {
                out.erroMsg = 'ORDER_NOT_FOUND';
                out.mensagemChat = '⚠️ Reserva não encontrada.';
                return new List<Output>{ out };
            }

            Order ord = ords[0];

            if (ord.Evento__r.DataEvento__c != null && ord.Evento__r.DataEvento__c < Date.today()) {
                out.erroMsg = 'EVENT_PAST';
                out.mensagemChat = '⚠️ Não é possível cancelar bilhetes para eventos passados.';
                return new List<Output>{ out };
            }

            if (ord.HasInsurance__c != true) {
                out.erroMsg = 'NO_INSURANCE';
                out.mensagemChat = '⚠️ Por política da empresa, reembolsos automáticos só são permitidos para compras com seguro ativo.';
                return new List<Output>{ out };
            }

            List<Bilhete__c> bList = [
                SELECT Id, EstadoBilhete__c, Fila__c, NumeroLugar__c
                FROM Bilhete__c
                WHERE Order__c = :targetOrderId
                AND   Fila__c  = :filaStr
                AND   NumeroLugar__c = :seatNum
                AND   EstadoBilhete__c = 'Vendido'
                LIMIT 1
            ];

            if (bList.isEmpty()) {
                out.erroMsg = 'BILHETE_NOT_FOUND';
                out.mensagemChat = '⚠️ Não encontrei o lugar ' + seatRaw + ' ativo nesta reserva.';
                return new List<Output>{ out };
            }
            
            Bilhete__c alvo = bList[0];
            alvo.EstadoBilhete__c = 'Cancelado';
            Database.update(alvo, true);

            out.sucesso = true;
            out.totalCancelados = 1;
            Decimal preco = ord.Evento__r.PrecoBilhete__c != null ? ord.Evento__r.PrecoBilhete__c : 0;
            String recinto = ord.Evento__r.Recinto__r.Name != null ? ord.Evento__r.Recinto__r.Name : 'Recinto';

            out.mensagemChat = '✅ Lugar **' + seatRaw + '** cancelado com sucesso.\n'
                + 'O lugar foi libertado no **' + recinto + '** e o valor de **' + preco + ' €** será reembolsado por teres o seguro ativo.';

        } catch (Exception e) {
            out.sucesso = false;
            out.erroMsg = e.getMessage();
            out.mensagemChat = '⚠️ Erro ao processar cancelamento: ' + e.getMessage();
        }

        return new List<Output>{ out };
    }
}
