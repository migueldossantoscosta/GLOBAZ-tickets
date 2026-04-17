public without sharing class MaintenancePricebookService {
    
    /**
     * @description Remove todos os pricebooks customizados e cria um novo para cada evento
     * com produtos e preços aleatórios para fins de demonstração.
     * Execute isto no Anonymous Window: MaintenancePricebookService.resetEverything();
     */
    public static void resetEverything() {
        // 1. Limpeza Profunda
        // Remover associações nos eventos primeiro para não dar erro de referência
        List<Evento__c> todosEventos = [SELECT Id, Name FROM Evento__c];
        for(Evento__c e : todosEventos) e.Pricebook__c = null;
        update todosEventos;

        // Desativar Pricebooks (exceto Standard) em vez de apagar (evita erro com Orders existentes)
        List<Pricebook2> pbs = [SELECT Id, Name FROM Pricebook2 WHERE IsStandard = false AND IsActive = true];
        if(!pbs.isEmpty()) {
            for(Pricebook2 pb : pbs) {
                if(!pb.Name.startsWith('[OBSOLETO]')) {
                    pb.Name = '[OBSOLETO] ' + pb.Name;
                }
                pb.IsActive = false;
            }
            update pbs;
        }

        // 2. Garantir que os Produtos existem
        Map<String, Product2> productsMap = ensureProducts();

        // 3. Obter Standard Pricebook ID
        Id stdPbId = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1].Id;

        // 4. Criar Entradas no Standard Pricebook (se não existirem)
        ensureStandardEntries(stdPbId, productsMap);

        // 5. Criar Pricebooks por Evento
        List<Pricebook2> newPbs = new List<Pricebook2>();
        for(Evento__c evt : todosEventos) {
            newPbs.add(new Pricebook2(
                Name = 'Pricebook - ' + evt.Name,
                IsActive = true,
                Description = 'Gerado automaticamente para o evento ' + evt.Name
            ));
        }
        insert newPbs;

        // Mapear Pricebook ao Evento
        for(Integer i=0; i < todosEventos.size(); i++) {
            todosEventos[i].Pricebook__c = newPbs[i].Id;
        }
        update todosEventos;

        // 6. Adicionar PricebookEntries aleatórios para cada Evento
        List<PricebookEntry> pbes = new List<PricebookEntry>();
        
        for(Pricebook2 pb : newPbs) {
            // Adicionar bilhetes base com preços aleatórios
            pbes.add(createPBE(pb.Id, productsMap.get('BLT-Geral').Id,    Decimal.valueOf(Math.random() * 40 + 20).setScale(2)));
            pbes.add(createPBE(pb.Id, productsMap.get('BLT-VIP').Id,      Decimal.valueOf(Math.random() * 80 + 70).setScale(2)));
            pbes.add(createPBE(pb.Id, productsMap.get('BLT-CAMAROTE').Id, Decimal.valueOf(Math.random() * 200 + 150).setScale(2)));

            // Adicionar 2-3 extras aleatórios
            if(Math.random() > 0.3) pbes.add(createPBE(pb.Id, productsMap.get('EXT-PARKING').Id, Decimal.valueOf(Math.random() * 15 + 5).setScale(2)));
            if(Math.random() > 0.5) pbes.add(createPBE(pb.Id, productsMap.get('EXT-BEV').Id,     Decimal.valueOf(Math.random() * 25 + 10).setScale(2)));
            if(Math.random() > 0.7) pbes.add(createPBE(pb.Id, productsMap.get('EXT-MEET').Id,    Decimal.valueOf(Math.random() * 100 + 50).setScale(2)));
            if(Math.random() > 0.8) pbes.add(createPBE(pb.Id, productsMap.get('EXT-FAST').Id,    Decimal.valueOf(Math.random() * 20 + 5).setScale(2)));
        }
        insert pbes;
    }

    private static Map<String, Product2> ensureProducts() {
        Map<String, Product2> results = new Map<String, Product2>();
        List<Product2> toCreate = new List<Product2>();
        
        Map<String, String> prodNames = new Map<String, String>{
            'BLT-Geral'    => 'Bilhete Geral',
            'BLT-VIP'      => 'Bilhete VIP',
            'BLT-CAMAROTE' => 'Bilhete Camarote',
            'EXT-PARKING'  => 'Estacionamento Premium',
            'EXT-BEV'      => 'Pack Bebidas GLOBAZ',
            'EXT-MEET'     => 'Meet & Greet Experience',
            'EXT-FAST'     => 'Fast Track - Acesso Rápido'
        };

        Map<String, Product2> existing = new Map<String, Product2>();
        for(Product2 p : [SELECT Id, ProductCode, Name FROM Product2 WHERE ProductCode IN :prodNames.keySet()]) {
            existing.put(p.ProductCode, p);
        }

        for(String code : prodNames.keySet()) {
            if(existing.containsKey(code)) {
                results.put(code, existing.get(code));
            } else {
                Product2 p = new Product2(Name = prodNames.get(code), ProductCode = code, IsActive = true);
                toCreate.add(p);
            }
        }

        if(!toCreate.isEmpty()) {
            insert toCreate;
            for(Product2 p : toCreate) results.put(p.ProductCode, p);
        }

        return results;
    }

    private static void ensureStandardEntries(Id stdPbId, Map<String, Product2> prodMap) {
        Set<Id> prodIds = new Set<Id>();
        for(Product2 p : prodMap.values()) prodIds.add(p.Id);

        Map<Id, PricebookEntry> existing = new Map<Id, PricebookEntry>();
        for(PricebookEntry pbe : [SELECT Product2Id FROM PricebookEntry WHERE Pricebook2Id = :stdPbId AND Product2Id IN :prodIds]) {
            existing.put(pbe.Product2Id, pbe);
        }

        List<PricebookEntry> toCreate = new List<PricebookEntry>();
        for(Product2 p : prodMap.values()) {
            if(!existing.containsKey(p.Id)) {
                toCreate.add(new PricebookEntry(
                    Pricebook2Id = stdPbId,
                    Product2Id = p.Id,
                    UnitPrice = 1.0, // Preço base negligenciável no standard
                    IsActive = true
                ));
            }
        }
        if(!toCreate.isEmpty()) insert toCreate;
    }

    private static PricebookEntry createPBE(Id pbId, Id pId, Decimal price) {
        return new PricebookEntry(
            Pricebook2Id = pbId,
            Product2Id = pId,
            UnitPrice = price,
            IsActive = true
        );
    }
}
