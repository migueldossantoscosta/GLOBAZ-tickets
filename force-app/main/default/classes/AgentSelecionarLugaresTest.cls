@isTest
private class AgentSelecionarLugaresTest {

    // ------------------------------------------------------------------ setup
    @TestSetup
    static void setup() {
        // nothing shared — each test uses AgentTestDataFactory inline
    }

    // ------------------------------------------------- happy path: frente, 1
    @isTest
    static void testSelecionarUmLugarFrente() {
        Account promotor = AgentTestDataFactory.createBusinessAccount();
        Evento__c ev     = AgentTestDataFactory.createEvento(promotor.Id);

        AgentSelecionarLugares.Input inp = new AgentSelecionarLugares.Input();
        inp.eventoId      = ev.Id;
        inp.quantidade    = 1;
        inp.zonaPreferida = 'frente';

        Test.startTest();
        List<AgentSelecionarLugares.Output> results =
            AgentSelecionarLugares.selecionarLugares(
                new List<AgentSelecionarLugares.Input>{ inp }
            );
        Test.stopTest();

        AgentSelecionarLugares.Output out = results[0];
        Assert.isTrue(out.sucesso,         'Devia encontrar um lugar');
        Assert.areEqual('A', out.fila,     'Primeiro lugar deve ser na fila A');
        Assert.areEqual(1, out.lugar,      'Primeiro lugar deve ser o número 1');
        Assert.isNotNull(out.lugaresJson,  'JSON de lugares não pode ser nulo');
        Assert.isTrue(out.mensagemChat.contains('Fila A'), 'Mensagem deve conter Fila A');
    }

    // ------------------------------------------- happy path: 2 lugares juntos
    @isTest
    static void testSelecionarDoisLugaresJuntos() {
        Account promotor = AgentTestDataFactory.createBusinessAccount();
        Evento__c ev     = AgentTestDataFactory.createEvento(promotor.Id);

        AgentSelecionarLugares.Input inp = new AgentSelecionarLugares.Input();
        inp.eventoId      = ev.Id;
        inp.quantidade    = 2;
        inp.zonaPreferida = 'frente';

        Test.startTest();
        List<AgentSelecionarLugares.Output> results =
            AgentSelecionarLugares.selecionarLugares(
                new List<AgentSelecionarLugares.Input>{ inp }
            );
        Test.stopTest();

        AgentSelecionarLugares.Output out = results[0];
        Assert.isTrue(out.sucesso, 'Devia encontrar 2 lugares');
        Assert.areEqual('A', out.fila);
        Assert.areEqual(1, out.lugar, 'Primeiro lugar do par deve ser A-1');

        // Verify JSON has 2 entries
        List<Object> parsed = (List<Object>) JSON.deserializeUntyped(out.lugaresJson);
        Assert.areEqual(2, parsed.size(), 'JSON deve ter 2 lugares');

        // Verify they are consecutive
        Map<String, Object> seat1 = (Map<String, Object>) parsed[0];
        Map<String, Object> seat2 = (Map<String, Object>) parsed[1];
        Integer n1 = Integer.valueOf(String.valueOf(seat1.get('lugar')));
        Integer n2 = Integer.valueOf(String.valueOf(seat2.get('lugar')));
        Assert.areEqual(1, n2 - n1, 'Os dois lugares devem ser consecutivos');
    }

    // ------------------------------ skips occupied seats and finds next pair
    @isTest
    static void testSkipsOccupiedAndFindsPair() {
        Account promotor = AgentTestDataFactory.createBusinessAccount();
        Evento__c ev     = AgentTestDataFactory.createEvento(promotor.Id);

        // Occupy A-1 so the first free pair must be A-2 & A-3
        Bilhete__c ocupado = new Bilhete__c(
            Evento__c        = ev.Id,
            Account__c       = promotor.Id,
            Fila__c          = 'A',
            NumeroLugar__c   = 1,
            EstadoBilhete__c = 'Vendido'
        );
        insert ocupado;

        AgentSelecionarLugares.Input inp = new AgentSelecionarLugares.Input();
        inp.eventoId      = ev.Id;
        inp.quantidade    = 2;
        inp.zonaPreferida = 'frente';

        Test.startTest();
        List<AgentSelecionarLugares.Output> results =
            AgentSelecionarLugares.selecionarLugares(
                new List<AgentSelecionarLugares.Input>{ inp }
            );
        Test.stopTest();

        AgentSelecionarLugares.Output out = results[0];
        Assert.isTrue(out.sucesso, 'Devia encontrar par mesmo com A-1 ocupado');
        Assert.areEqual('A', out.fila);
        Assert.areEqual(2, out.lugar, 'Par livre deve começar em A-2');
    }

    // -------------- skips non-consecutive gap and finds first consecutive run
    @isTest
    static void testSkipsGapFindsFirstConsecutiveRun() {
        Account promotor = AgentTestDataFactory.createBusinessAccount();
        Evento__c ev     = AgentTestDataFactory.createEvento(promotor.Id);

        // Occupy A-1 and A-3, leaving A-2 isolated — first pair must be A-4 & A-5
        List<Bilhete__c> toInsert = new List<Bilhete__c>{
            new Bilhete__c(Evento__c=ev.Id, Account__c=promotor.Id, Fila__c='A', NumeroLugar__c=1, EstadoBilhete__c='Vendido'),
            new Bilhete__c(Evento__c=ev.Id, Account__c=promotor.Id, Fila__c='A', NumeroLugar__c=3, EstadoBilhete__c='Vendido')
        };
        insert toInsert;

        AgentSelecionarLugares.Input inp = new AgentSelecionarLugares.Input();
        inp.eventoId      = ev.Id;
        inp.quantidade    = 2;
        inp.zonaPreferida = 'frente';

        Test.startTest();
        List<AgentSelecionarLugares.Output> results =
            AgentSelecionarLugares.selecionarLugares(
                new List<AgentSelecionarLugares.Input>{ inp }
            );
        Test.stopTest();

        AgentSelecionarLugares.Output out = results[0];
        Assert.isTrue(out.sucesso);
        // A-2 is isolated (A-1 and A-3 occupied) → first free consecutive pair is A-4 & A-5
        Assert.areEqual('A', out.fila);
        Assert.areEqual(4, out.lugar, 'Primeiro par livre deve começar em A-4');
    }

    // ----------------------------- zone 'meio' picks row D before A
    @isTest
    static void testZonaMeio() {
        Account promotor = AgentTestDataFactory.createBusinessAccount();
        Evento__c ev     = AgentTestDataFactory.createEvento(promotor.Id);

        AgentSelecionarLugares.Input inp = new AgentSelecionarLugares.Input();
        inp.eventoId      = ev.Id;
        inp.quantidade    = 1;
        inp.zonaPreferida = 'meio';

        Test.startTest();
        List<AgentSelecionarLugares.Output> results =
            AgentSelecionarLugares.selecionarLugares(
                new List<AgentSelecionarLugares.Input>{ inp }
            );
        Test.stopTest();

        AgentSelecionarLugares.Output out = results[0];
        Assert.isTrue(out.sucesso);
        // With no occupied seats, first seat in zone 'meio' must be D-1
        Assert.areEqual('D', out.fila, 'Zona meio deve começar na fila D');
        Assert.areEqual(1, out.lugar);
    }

    // --------------------------------- full row A occupied → falls back to B
    @isTest
    static void testFullRowAFallsBackToB() {
        Account promotor = AgentTestDataFactory.createBusinessAccount();
        Evento__c ev     = AgentTestDataFactory.createEvento(promotor.Id);

        // Fill all 20 seats of row A
        List<Bilhete__c> rowA = new List<Bilhete__c>();
        for (Integer i = 1; i <= 20; i++) {
            rowA.add(new Bilhete__c(
                Evento__c        = ev.Id,
                Account__c       = promotor.Id,
                Fila__c          = 'A',
                NumeroLugar__c   = i,
                EstadoBilhete__c = 'Vendido'
            ));
        }
        insert rowA;

        AgentSelecionarLugares.Input inp = new AgentSelecionarLugares.Input();
        inp.eventoId      = ev.Id;
        inp.quantidade    = 2;
        inp.zonaPreferida = 'frente';

        Test.startTest();
        List<AgentSelecionarLugares.Output> results =
            AgentSelecionarLugares.selecionarLugares(
                new List<AgentSelecionarLugares.Input>{ inp }
            );
        Test.stopTest();

        AgentSelecionarLugares.Output out = results[0];
        Assert.isTrue(out.sucesso, 'Devia encontrar lugares na fila B');
        Assert.areEqual('B', out.fila, 'Deve cair para fila B quando A está cheia');
        Assert.areEqual(1, out.lugar);
    }

    // --------------------------------- invalid event ID returns error
    @isTest
    static void testInvalidEventId() {
        AgentSelecionarLugares.Input inp = new AgentSelecionarLugares.Input();
        inp.eventoId   = 'invalid_id';
        inp.quantidade = 1;

        Test.startTest();
        List<AgentSelecionarLugares.Output> results =
            AgentSelecionarLugares.selecionarLugares(
                new List<AgentSelecionarLugares.Input>{ inp }
            );
        Test.stopTest();

        Assert.isFalse(results[0].sucesso, 'ID inválido deve retornar erro');
        Assert.isNotNull(results[0].erroMsg);
    }
}