package samples;

enum CarEffect {
    PlaySound(id:String);
    StopSound(id:String);
    SetHeadlights(active:Bool);
    SetDashboardPower(active:Bool);
}

